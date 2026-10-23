data "aws_region" "current" {}

locals {
  region           = data.aws_region.current.region
  gitops_root_path = coalesce(var.gitops_root_path, "clusters/${var.cluster_name}")

  # Every addon controller runs on Karpenter capacity; only the system node
  # group is tainted, so no tolerations are needed here.
  common_resources = {
    requests = { cpu = "50m", memory = "64Mi" }
  }
}

################################################################################
# AWS Load Balancer Controller
################################################################################

module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"
  count   = var.enable_aws_load_balancer_controller ? 1 : 0

  name = "${var.cluster_name}-aws-lbc"

  attach_aws_lb_controller_policy = true

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = "kube-system"
      service_account = "aws-load-balancer-controller"
    }
  }

  tags = var.tags
}

resource "helm_release" "aws_load_balancer_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.chart_versions.aws_load_balancer_controller

  values = [yamlencode({
    clusterName  = var.cluster_name
    region       = local.region
    vpcId        = var.vpc_id
    replicaCount = 2
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
    }
    # Default new Services of type LoadBalancer to NLB via this controller.
    enableServiceMutatorWebhook = true
  })]

  depends_on = [module.aws_lb_controller_pod_identity]
}

################################################################################
# external-dns
################################################################################

module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"
  count   = var.enable_external_dns ? 1 : 0

  name = "${var.cluster_name}-external-dns"

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = var.external_dns_hosted_zone_arns

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }

  tags = var.tags
}

resource "helm_release" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  name             = "external-dns"
  namespace        = "external-dns"
  create_namespace = true
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  version          = var.chart_versions.external_dns

  values = [yamlencode({
    provider = { name = "aws" }
    serviceAccount = {
      create = true
      name   = "external-dns"
    }
    sources       = ["service", "ingress"]
    domainFilters = var.external_dns_domain_filters
    policy        = var.external_dns_policy
    registry      = "txt"
    # Unique per cluster so primary and DR never fight over the same records.
    txtOwnerId = var.cluster_name
    env = [
      { name = "AWS_DEFAULT_REGION", value = local.region },
    ]
    resources = local.common_resources
  })]

  depends_on = [module.external_dns_pod_identity]
}

################################################################################
# cert-manager
################################################################################

module "cert_manager_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"
  count   = var.enable_cert_manager ? 1 : 0

  name = "${var.cluster_name}-cert-manager"

  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = var.cert_manager_hosted_zone_arns

  associations = {
    this = {
      cluster_name    = var.cluster_name
      namespace       = "cert-manager"
      service_account = "cert-manager"
    }
  }

  tags = var.tags
}

resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.chart_versions.cert_manager

  values = [yamlencode({
    crds = { enabled = true, keep = true }
    serviceAccount = {
      create = true
      name   = "cert-manager"
    }
    # Use public resolvers for DNS-01 self-checks so split-horizon zones do not stall issuance.
    extraArgs = [
      "--dns01-recursive-nameservers-only",
      "--dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53",
    ]
    resources = local.common_resources
  })]

  depends_on = [module.cert_manager_pod_identity]
}

################################################################################
# metrics-server
################################################################################

resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0

  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = var.chart_versions.metrics_server

  values = [yamlencode({
    replicas = 2
    podDisruptionBudget = {
      enabled      = true
      minAvailable = 1
    }
  })]
}

################################################################################
# KEDA
################################################################################

resource "helm_release" "keda" {
  count = var.enable_keda ? 1 : 0

  name             = "keda"
  namespace        = "keda"
  create_namespace = true
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  version          = var.chart_versions.keda

  values = [yamlencode({
    # The operator gets no AWS permissions here. Scalers that need AWS access
    # (SQS, CloudWatch) are granted roles per workload via TriggerAuthentication.
    resources = {
      operator = {
        requests = { cpu = "100m", memory = "128Mi" }
      }
    }
  })]

  depends_on = [helm_release.metrics_server]
}

################################################################################
# Argo CD + app-of-apps bootstrap
################################################################################

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_versions.argo_cd

  values = [yamlencode({
    configs = {
      params = {
        # TLS is terminated at the ALB in front of argocd-server.
        "server.insecure" = true
      }
      cm = {
        "application.resourceTrackingMethod" = "annotation"
      }
    }
    "redis-ha" = { enabled = var.argocd_ha }
    controller = { replicas = 1 }
    server     = { replicas = var.argocd_ha ? 2 : 1 }
    repoServer = { replicas = var.argocd_ha ? 2 : 1 }
    applicationSet = {
      replicas = var.argocd_ha ? 2 : 1
    }
  })]
}

resource "helm_release" "argocd_root_app" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd-root"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.chart_versions.argocd_apps

  values = [yamlencode({
    applications = {
      root = {
        namespace  = "argocd"
        project    = "default"
        finalizers = ["resources-finalizer.argocd.argoproj.io"]
        source = {
          repoURL        = var.gitops_repo_url
          targetRevision = var.gitops_repo_revision
          path           = local.gitops_root_path
          directory      = { recurse = true }
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "argocd"
        }
        syncPolicy = {
          automated = {
            prune    = true
            selfHeal = true
          }
          syncOptions = ["CreateNamespace=true"]
        }
      }
    }
  })]

  depends_on = [helm_release.argocd]
}
