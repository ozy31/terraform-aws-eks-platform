locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules//vpc"
}

inputs = {
  name               = local.env.cluster_name
  cluster_name       = local.env.cluster_name
  cidr               = local.env.vpc_cidr
  single_nat_gateway = local.env.single_nat_gateway
}
