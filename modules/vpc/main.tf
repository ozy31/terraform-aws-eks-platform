data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = coalesce(var.azs, slice(data.aws_availability_zones.available.names, 0, 3))

  # Deterministic layout for a /16:
  #   private  /19 x3  -> 10.x.0.0   - 10.x.95.255  (nodes + pods, VPC CNI needs lots of IPs)
  #   public   /24 x3  -> 10.x.96.0  - 10.x.98.255  (NAT gateways, internet-facing ALB/NLB)
  #   intra    /24 x3  -> 10.x.104.0 - 10.x.106.255 (EKS control plane ENIs, no internet route)
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.cidr, 3, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, 96 + i)]
  intra_subnets   = [for i, _ in local.azs : cidrsubnet(var.cidr, 8, 104 + i)]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = var.name
  cidr = var.cidr
  azs  = local.azs

  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Lock down the default SG/NACL/route table so nothing accidentally uses them.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    # Karpenter's EC2NodeClass selects subnets by this tag.
    "karpenter.sh/discovery" = var.cluster_name
  }

  enable_flow_log                                 = var.enable_flow_logs
  create_flow_log_cloudwatch_log_group            = var.enable_flow_logs
  create_flow_log_cloudwatch_iam_role             = var.enable_flow_logs
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = var.flow_logs_retention_in_days

  tags = var.tags
}
