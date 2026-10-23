# Development: single NAT, small limits, spot-heavy. Cheap to run, cheap to break.
locals {
  environment    = "dev"
  aws_region     = "eu-west-1"
  aws_account_id = "111111111111" # placeholder

  cluster_name       = "eks-dev"
  kubernetes_version = "1.34"
  vpc_cidr           = "10.10.0.0/16"
  single_nat_gateway = true

  deletion_protection     = false
  admin_principal_arns    = ["arn:aws:iam::111111111111:role/platform-admin"]
  readonly_principal_arns = ["arn:aws:iam::111111111111:role/developer"]

  system_node_group = {
    instance_types = ["t3a.large", "t3.large"]
    min_size       = 2
    max_size       = 3
    desired_size   = 2
  }

  karpenter = {
    node_os        = "bottlerocket"
    capacity_types = ["spot", "on-demand"]
    cpu_limit      = 64
  }

  route53_zone_arns  = ["arn:aws:route53:::hostedzone/Z00000000000000000DEV"] # placeholder
  dns_domain_filters = ["dev.example.com"]

  argocd_ha            = false
  gitops_repo_url      = "https://github.com/ozy31/gitops-multicluster-dr.git"
  gitops_repo_revision = "main"
}
