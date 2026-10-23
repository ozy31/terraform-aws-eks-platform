# Production primary region. NAT per AZ, deletion protection, HA Argo CD.
locals {
  environment    = "prod"
  aws_region     = "eu-west-1"
  aws_account_id = "222222222222" # placeholder

  cluster_name       = "eks-prod"
  kubernetes_version = "1.34"
  vpc_cidr           = "10.30.0.0/16"
  single_nat_gateway = false

  deletion_protection     = true
  admin_principal_arns    = ["arn:aws:iam::222222222222:role/platform-admin"]
  readonly_principal_arns = ["arn:aws:iam::222222222222:role/sre-readonly"]

  system_node_group = {
    instance_types = ["m7i.large", "m6i.large"]
    min_size       = 3
    max_size       = 5
    desired_size   = 3
  }

  karpenter = {
    node_os        = "bottlerocket"
    capacity_types = ["spot", "on-demand"]
    cpu_limit      = 1000
  }

  # Regional sub-zone; the global record is switched by gitops-multicluster-dr.
  route53_zone_arns  = ["arn:aws:route53:::hostedzone/Z0000000000000000EUW1"] # placeholder
  dns_domain_filters = ["euw1.prod.example.com"]

  argocd_ha            = true
  gitops_repo_url      = "https://github.com/ozy31/gitops-multicluster-dr.git"
  gitops_repo_revision = "main"
}
