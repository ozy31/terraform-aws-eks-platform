locals {
  system_ng = var.system_node_group

  # Bottlerocket keeps the OS on /dev/xvda and container data on /dev/xvdb.
  system_ng_data_device = startswith(local.system_ng.ami_type, "BOTTLEROCKET") ? "/dev/xvdb" : "/dev/xvda"

  admin_access_entries = {
    for arn in var.admin_principal_arns : "admin-${md5(arn)}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  readonly_access_entries = {
    for arn in var.readonly_principal_arns : "readonly-${md5(arn)}" => {
      principal_arn = arn
      policy_associations = {
        view = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
}

################################################################################
# EKS cluster
################################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = length(var.control_plane_subnet_ids) > 0 ? var.control_plane_subnet_ids : var.subnet_ids

  endpoint_private_access      = true
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs

  deletion_protection = var.deletion_protection

  # Access entries only; aws-auth ConfigMap is not used.
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = var.enable_cluster_creator_admin_permissions
  access_entries                           = merge(local.admin_access_entries, local.readonly_access_entries)

  # Envelope encryption of Kubernetes Secrets with a module-managed, rotated CMK.
  create_kms_key          = true
  enable_kms_key_rotation = true
  kms_key_administrators  = var.kms_key_administrators
  encryption_config = {
    resources = ["secrets"]
  }

  enabled_log_types                      = var.enabled_log_types
  cloudwatch_log_group_retention_in_days = var.cloudwatch_log_retention_in_days

  # IRSA stays available for charts that do not support Pod Identity yet;
  # everything this repo installs uses EKS Pod Identity.
  enable_irsa = true

  addons = {
    # Networking and Pod Identity must exist before any node joins.
    vpc-cni = {
      before_compute = true
      addon_version  = lookup(var.addon_versions, "vpc-cni", null)
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
      addon_version  = lookup(var.addon_versions, "eks-pod-identity-agent", null)
    }
    kube-proxy = {
      addon_version = lookup(var.addon_versions, "kube-proxy", null)
    }
    coredns = {
      addon_version = lookup(var.addon_versions, "coredns", null)
      configuration_values = jsonencode({
        tolerations = [{ key = "CriticalAddonsOnly", operator = "Exists" }]
      })
    }
    aws-ebs-csi-driver = {
      addon_version = lookup(var.addon_versions, "aws-ebs-csi-driver", null)
      pod_identity_association = [{
        role_arn        = module.ebs_csi_pod_identity.iam_role_arn
        service_account = "ebs-csi-controller-sa"
      }]
    }
  }

  eks_managed_node_groups = {
    system = {
      ami_type       = local.system_ng.ami_type
      instance_types = local.system_ng.instance_types
      capacity_type  = local.system_ng.capacity_type

      min_size     = local.system_ng.min_size
      max_size     = local.system_ng.max_size
      desired_size = local.system_ng.desired_size

      labels = {
        "node.kubernetes.io/role" = "system"
        # Karpenter's controller is pinned here so it never runs on capacity it manages.
        "karpenter.sh/controller" = "true"
      }

      taints = local.system_ng.taint_critical ? {
        critical = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      } : {}

      block_device_mappings = {
        data = {
          device_name = local.system_ng_data_device
          ebs = {
            volume_size           = local.system_ng.disk_size_gib
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      iam_role_additional_policies = {
        ssm = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      update_config = {
        max_unavailable = 1
      }
    }
  }

  node_security_group_tags = {
    # Karpenter's EC2NodeClass selects security groups by this tag.
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}

data "aws_partition" "current" {}

################################################################################
# Pod Identity role for the EBS CSI driver addon
################################################################################

module "ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name = "${var.cluster_name}-ebs-csi"

  attach_aws_ebs_csi_policy = true

  tags = var.tags
}
