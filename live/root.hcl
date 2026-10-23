# Root Terragrunt configuration, included by every unit under live/.
#
# Layout: live/<env>/<unit>/terragrunt.hcl
#   - env.hcl in each environment folder carries account, region and sizing.
#   - _envcommon/<unit>.hcl carries the module source and cross-unit wiring.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  environment    = local.env_vars.locals.environment
  aws_region     = local.env_vars.locals.aws_region
  aws_account_id = local.env_vars.locals.aws_account_id

  default_tags = {
    Environment = local.environment
    ManagedBy   = "terragrunt"
    Repository  = "github.com/ozy31/terraform-aws-eks-platform"
  }
}

# State lives in the same region as the stack it describes, so the DR stack can
# still be planned and applied when the primary region is unavailable.
# Locking uses S3 native conditional writes (use_lockfile); no DynamoDB table.
remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "tfstate-${local.aws_account_id}-${local.aws_region}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

generate "provider_aws" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${local.aws_region}"
      allowed_account_ids = ["${local.aws_account_id}"]

      default_tags {
        tags = ${jsonencode(local.default_tags)}
      }
    }
  EOF
}

inputs = {
  tags = local.default_tags
}
