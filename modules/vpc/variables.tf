variable "name" {
  description = "Name prefix for the VPC and all of its child resources."
  type        = string
}

variable "cidr" {
  description = "IPv4 CIDR block for the VPC. Must be a /16; subnets are carved out of it deterministically (see README)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.cidr)) && endswith(var.cidr, "/16")
    error_message = "cidr must be a valid IPv4 /16 block, e.g. 10.10.0.0/16."
  }
}

variable "azs" {
  description = "Availability zones to spread subnets across. Defaults to the first three AZs of the current region."
  type        = list(string)
  default     = null

  validation {
    condition     = var.azs == null || try(length(var.azs) == 3, false)
    error_message = "Exactly three availability zones are required."
  }
}

variable "cluster_name" {
  description = "Name of the EKS cluster that will live in this VPC. Used for Karpenter discovery and load balancer subnet tags."
  type        = string
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ. Cheaper, but an AZ outage takes down egress for the whole VPC. Recommended only for non-production."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Ship VPC flow logs to a dedicated CloudWatch log group."
  type        = bool
  default     = true
}

variable "flow_logs_retention_in_days" {
  description = "Retention for the VPC flow log CloudWatch log group."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every resource created by this module."
  type        = map(string)
  default     = {}
}
