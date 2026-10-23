locals {
  tags = {
    Project   = "eks-platform"
    Example   = "complete"
    ManagedBy = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name         = var.name
  cidr         = "10.20.0.0/16"
  cluster_name = var.name

  # Example only: one NAT gateway keeps the bill down. Production uses one per AZ.
  single_nat_gateway = true

  tags = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name       = var.name
  kubernetes_version = "1.34"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnet_ids
  control_plane_subnet_ids = module.vpc.intra_subnet_ids

  # The API stays private unless you pass your own CIDR(s), e.g. ["203.0.113.10/32"].
  endpoint_public_access                   = length(var.api_allowed_cidrs) > 0
  endpoint_public_access_cidrs             = var.api_allowed_cidrs
  enable_cluster_creator_admin_permissions = true
  admin_principal_arns                     = var.admin_principal_arns

  system_node_group = {
    instance_types = ["t3a.large", "t3.large"]
    desired_size   = 2
  }

  tags = local.tags
}

module "karpenter" {
  source = "../../modules/karpenter"

  cluster_name     = module.eks.cluster_name
  cluster_endpoint = module.eks.cluster_endpoint

  node_os        = "bottlerocket"
  capacity_types = ["spot", "on-demand"]
  cpu_limit      = 64

  tags = local.tags
}

module "platform_addons" {
  source = "../../modules/platform-addons"

  cluster_name = module.eks.cluster_name
  vpc_id       = module.vpc.vpc_id

  # No Route 53 zone in the example.
  enable_external_dns = false

  gitops_repo_url  = var.gitops_repo_url
  gitops_root_path = "clusters/example"

  tags = local.tags

  # Addon controllers schedule onto Karpenter capacity.
  depends_on = [module.karpenter]
}
