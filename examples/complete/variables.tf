variable "region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-west-1"
}

variable "name" {
  description = "Name used for the VPC and the EKS cluster."
  type        = string
  default     = "platform-example"
}

variable "api_allowed_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API. Empty keeps the endpoint private-only."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.api_allowed_cidrs, "0.0.0.0/0")
    error_message = "Refusing to expose the Kubernetes API to 0.0.0.0/0; pass specific CIDRs."
  }
}

variable "admin_principal_arns" {
  description = "IAM principals granted cluster-admin via EKS access entries."
  type        = list(string)
  default     = []
}

variable "gitops_repo_url" {
  description = "GitOps repository bootstrapped into Argo CD."
  type        = string
  default     = "https://github.com/ozy31/gitops-multicluster-dr.git"
}
