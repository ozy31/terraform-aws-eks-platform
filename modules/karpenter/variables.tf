variable "cluster_name" {
  description = "Name of the EKS cluster Karpenter manages."
  type        = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint of the cluster. Passed to Karpenter to avoid an extra DescribeCluster call."
  type        = string
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version (OCI chart at public.ecr.aws/karpenter/karpenter)."
  type        = string
  default     = "1.15.0"
}

variable "namespace" {
  description = "Namespace the Karpenter controller runs in."
  type        = string
  default     = "kube-system"
}

variable "controller_replicas" {
  description = "Number of Karpenter controller replicas (leader-elected)."
  type        = number
  default     = 2
}

variable "node_os" {
  description = "Operating system for Karpenter-provisioned nodes: \"al2023\" or \"bottlerocket\"."
  type        = string
  default     = "al2023"

  validation {
    condition     = contains(["al2023", "bottlerocket"], var.node_os)
    error_message = "node_os must be either \"al2023\" or \"bottlerocket\"."
  }
}

variable "ami_alias_version" {
  description = "AMI alias version for the EC2NodeClass (e.g. \"latest\" or a pinned \"v20250715\"). Pin in production and roll forward deliberately."
  type        = string
  default     = "latest"
}

variable "node_volume_size_gib" {
  description = "Size of the node data volume (root volume on AL2023, data volume on Bottlerocket)."
  type        = number
  default     = 50
}

variable "capacity_types" {
  description = "Capacity types the default NodePool may launch. With both, Karpenter prefers spot and falls back to on-demand."
  type        = list(string)
  default     = ["spot", "on-demand"]

  validation {
    condition     = length(var.capacity_types) > 0 && alltrue([for c in var.capacity_types : contains(["spot", "on-demand", "reserved"], c)])
    error_message = "capacity_types may only contain \"spot\", \"on-demand\" and \"reserved\"."
  }
}

variable "architectures" {
  description = "CPU architectures allowed in the default NodePool."
  type        = list(string)
  default     = ["amd64"]
}

variable "instance_categories" {
  description = "EC2 instance categories allowed in the default NodePool. A wide set gives the spot allocator more pools to choose from."
  type        = list(string)
  default     = ["c", "m", "r"]
}

variable "instance_generation_greater_than" {
  description = "Only allow instance generations strictly greater than this value."
  type        = number
  default     = 5
}

variable "cpu_limit" {
  description = "Upper bound of total vCPU the default NodePool may provision. Acts as a cost circuit breaker."
  type        = number
  default     = 1000
}

variable "memory_limit" {
  description = "Upper bound of total memory the default NodePool may provision (Kubernetes quantity)."
  type        = string
  default     = "4000Gi"
}

variable "consolidation_policy" {
  description = "Karpenter consolidation policy: WhenEmptyOrUnderutilized or WhenEmpty."
  type        = string
  default     = "WhenEmptyOrUnderutilized"

  validation {
    condition     = contains(["WhenEmptyOrUnderutilized", "WhenEmpty"], var.consolidation_policy)
    error_message = "consolidation_policy must be WhenEmptyOrUnderutilized or WhenEmpty."
  }
}

variable "consolidate_after" {
  description = "How long a node must be consolidatable before Karpenter acts on it."
  type        = string
  default     = "1m"
}

variable "expire_after" {
  description = "Maximum node lifetime; forces regular node rotation onto fresh AMIs."
  type        = string
  default     = "720h"
}

variable "disruption_budgets" {
  description = "Karpenter disruption budgets for the default NodePool."
  type = list(object({
    nodes    = string
    schedule = optional(string)
    duration = optional(string)
    reasons  = optional(list(string))
  }))
  default = [{ nodes = "10%" }]
}

variable "tags" {
  description = "Tags applied to AWS resources created by this module and to every EC2 instance Karpenter launches."
  type        = map(string)
  default     = {}
}
