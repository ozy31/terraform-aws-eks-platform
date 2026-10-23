locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl")).locals
}

terraform {
  source = "${dirname(find_in_parent_folders("root.hcl"))}/../modules//platform-addons"
}

dependency "vpc" {
  config_path = "${get_terragrunt_dir()}/../vpc"

  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "eks" {
  config_path = "${get_terragrunt_dir()}/../eks"

  mock_outputs = {
    cluster_name                       = "mock-cluster"
    cluster_endpoint                   = "https://mock.eks.amazonaws.com"
    cluster_certificate_authority_data = "bW9jaw=="
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# Addon controllers schedule onto Karpenter capacity, so Karpenter goes first.
dependencies {
  paths = ["${get_terragrunt_dir()}/../karpenter"]
}

generate "provider_helm" {
  path      = "provider_helm.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "helm" {
      kubernetes = {
        host                   = "${dependency.eks.outputs.cluster_endpoint}"
        cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
        exec = {
          api_version = "client.authentication.k8s.io/v1beta1"
          command     = "aws"
          args        = ["eks", "get-token", "--cluster-name", "${dependency.eks.outputs.cluster_name}", "--region", "${local.env.aws_region}"]
        }
      }
    }
  EOF
}

inputs = {
  cluster_name = dependency.eks.outputs.cluster_name
  vpc_id       = dependency.vpc.outputs.vpc_id

  external_dns_hosted_zone_arns = local.env.route53_zone_arns
  external_dns_domain_filters   = local.env.dns_domain_filters
  cert_manager_hosted_zone_arns = local.env.route53_zone_arns

  argocd_ha            = local.env.argocd_ha
  gitops_repo_url      = local.env.gitops_repo_url
  gitops_repo_revision = local.env.gitops_repo_revision
}
