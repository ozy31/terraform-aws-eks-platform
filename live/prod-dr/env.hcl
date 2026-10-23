# Production DR in a second region. Same shape as prod so failover is a traffic
# decision, not a capacity scramble; Karpenter keeps idle cost close to the
# system node group until workloads actually land here.
locals {
  environment    = "prod-dr"
  aws_region     = "eu-central-1"
  aws_account_id = "222222222222" # placeholder, same account as prod

  cluster_name       = "eks-prod-dr"
  kubernetes_version = "1.34"
  vpc_cidr           = "10.40.0.0/16" # non-overlapping with prod for future peering/TGW
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

  route53_zone_arns  = ["arn:aws:route53:::hostedzone/Z0000000000000000EUC1"] # placeholder
  dns_domain_filters = ["euc1.prod.example.com"]

  argocd_ha            = true
  gitops_repo_url      = "https://github.com/ozy31/gitops-multicluster-dr.git"
  gitops_repo_revision = "main"
}
