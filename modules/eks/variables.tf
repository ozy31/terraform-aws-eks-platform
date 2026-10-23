variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane and the system node group, e.g. \"1.34\"."
  type        = string
  default     = "1.34"
}

variable "vpc_id" {
  description = "ID of the VPC the cluster is deployed into."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for worker nodes (system node group and, via discovery tags, Karpenter nodes)."
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "Subnet IDs for the EKS control plane ENIs. Typically the intra subnets. Defaults to subnet_ids when empty."
  type        = list(string)
  default     = []
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API endpoint publicly. Keep false and reach the API over VPN/TGW where possible."
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint when endpoint_public_access is true."
  type        = list(string)
  default     = []
}

variable "admin_principal_arns" {
  description = "IAM role/user ARNs granted cluster-admin through EKS access entries (e.g. an SSO admin role and the CI deploy role)."
  type        = list(string)
  default     = []
}

variable "readonly_principal_arns" {
  description = "IAM role/user ARNs granted cluster-wide read-only access through EKS access entries."
  type        = list(string)
  default     = []
}

variable "enable_cluster_creator_admin_permissions" {
  description = "Grant the identity running Terraform cluster-admin. Handy for bootstrap; prefer explicit admin_principal_arns for long-lived clusters."
  type        = bool
  default     = false
}

variable "kms_key_administrators" {
  description = "IAM ARNs allowed to administer the KMS key used for secrets envelope encryption. Defaults to the caller identity."
  type        = list(string)
  default     = []
}

variable "enabled_log_types" {
  description = "Control plane log types shipped to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "cloudwatch_log_retention_in_days" {
  description = "Retention for the control plane CloudWatch log group."
  type        = number
  default     = 90
}

variable "deletion_protection" {
  description = "Enable EKS cluster deletion protection. Strongly recommended for production clusters."
  type        = bool
  default     = false
}

variable "system_node_group" {
  description = <<-EOT
    Managed node group that hosts cluster-critical components (CoreDNS, Karpenter controller, EBS CSI controller).
    It is tainted with CriticalAddonsOnly so application workloads land on Karpenter-provisioned nodes instead.
  EOT
  type = object({
    instance_types = optional(list(string), ["m7i.large", "m6i.large"])
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = optional(number, 2)
    max_size       = optional(number, 4)
    desired_size   = optional(number, 2)
    disk_size_gib  = optional(number, 50)
    taint_critical = optional(bool, true)
  })
  default = {}
}

variable "addon_versions" {
  description = "Optional pinned versions for EKS managed addons, keyed by addon name. Unpinned addons track the most recent version compatible with the cluster."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
