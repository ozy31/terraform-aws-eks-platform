locals {
  service_account = "karpenter"

  # Drop unset optional attributes so the rendered NodePool only carries what was configured.
  disruption_budgets = [
    for b in var.disruption_budgets : merge(
      { nodes = b.nodes },
      b.schedule != null ? { schedule = b.schedule } : {},
      b.duration != null ? { duration = b.duration } : {},
      b.reasons != null ? { reasons = b.reasons } : {},
    )
  ]
}

################################################################################
# IAM: controller role (Pod Identity), node role, access entry, SQS interruption queue
################################################################################

module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.29.0"

  cluster_name = var.cluster_name

  namespace                       = var.namespace
  service_account                 = local.service_account
  create_pod_identity_association = true

  # Spot interruption, rebalance and scheduled-change events land in SQS so
  # Karpenter can cordon and drain ahead of the two-minute reclaim.
  enable_spot_termination = true

  # Stable node role name so the EC2NodeClass can reference it directly.
  node_iam_role_use_name_prefix = false
  node_iam_role_name            = "${var.cluster_name}-karpenter-node"
  node_iam_role_additional_policies = {
    ssm = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}

data "aws_partition" "current" {}

################################################################################
# Karpenter controller
################################################################################

resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = var.namespace
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = var.karpenter_version

  wait = true

  values = [yamlencode({
    replicas = var.controller_replicas

    serviceAccount = {
      name = module.karpenter.service_account
    }

    settings = {
      clusterName       = var.cluster_name
      clusterEndpoint   = var.cluster_endpoint
      interruptionQueue = module.karpenter.queue_name
    }

    # Run only on the managed system node group, never on Karpenter capacity.
    nodeSelector = {
      "karpenter.sh/controller" = "true"
    }
    tolerations = [
      { key = "CriticalAddonsOnly", operator = "Exists" },
    ]

    # Resolve DNS via the VPC resolver so Karpenter can start before CoreDNS has capacity.
    dnsPolicy = "Default"

    controller = {
      resources = {
        requests = { cpu = "500m", memory = "512Mi" }
        limits   = { memory = "512Mi" }
      }
    }
  })]
}

################################################################################
# Default EC2NodeClass + NodePool
#
# Shipped as a tiny local chart instead of kubernetes_manifest so that `plan`
# does not need the Karpenter CRDs to exist yet.
################################################################################

resource "helm_release" "karpenter_resources" {
  name      = "karpenter-resources"
  namespace = var.namespace
  chart     = "${path.module}/charts/karpenter-resources"

  values = [yamlencode({
    clusterName = var.cluster_name
    nodeRole    = module.karpenter.node_iam_role_name
    tags        = var.tags

    nodeClass = {
      name              = "default"
      os                = var.node_os
      amiAliasVersion   = var.ami_alias_version
      rootVolumeSizeGiB = var.node_volume_size_gib
    }

    nodePool = {
      name                          = "default"
      capacityTypes                 = var.capacity_types
      architectures                 = var.architectures
      instanceCategories            = var.instance_categories
      instanceGenerationGreaterThan = tostring(var.instance_generation_greater_than)
      cpuLimit                      = tostring(var.cpu_limit)
      memoryLimit                   = var.memory_limit
      expireAfter                   = var.expire_after
      consolidationPolicy           = var.consolidation_policy
      consolidateAfter              = var.consolidate_after
      disruptionBudgets             = local.disruption_budgets
    }
  })]

  depends_on = [helm_release.karpenter]
}
