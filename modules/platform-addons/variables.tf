variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID of the cluster. Passed explicitly to the AWS Load Balancer Controller because nodes block IMDS from pods."
  type        = string
}

variable "chart_versions" {
  description = "Pinned Helm chart versions. Override individual keys to upgrade a single addon."
  type = object({
    aws_load_balancer_controller = optional(string, "3.6.1")
    external_dns                 = optional(string, "1.23.0")
    cert_manager                 = optional(string, "v1.21.2")
    keda                         = optional(string, "2.21.0")
    metrics_server               = optional(string, "3.14.0")
    argo_cd                      = optional(string, "10.10.5")
    argocd_apps                  = optional(string, "2.0.7")
  })
  default = {}
}

# --- AWS Load Balancer Controller --------------------------------------------

variable "enable_aws_load_balancer_controller" {
  description = "Install the AWS Load Balancer Controller."
  type        = bool
  default     = true
}

# --- external-dns ------------------------------------------------------------

variable "enable_external_dns" {
  description = "Install external-dns for Route 53."
  type        = bool
  default     = true
}

variable "external_dns_hosted_zone_arns" {
  description = "Route 53 hosted zone ARNs external-dns may modify. The IAM policy is scoped to exactly these zones."
  type        = list(string)
  default     = []
}

variable "external_dns_domain_filters" {
  description = "Domains external-dns is allowed to manage records for."
  type        = list(string)
  default     = []
}

variable "external_dns_policy" {
  description = "external-dns sync policy. \"upsert-only\" never deletes records, which is the safer default when two clusters (primary and DR) share a zone."
  type        = string
  default     = "upsert-only"

  validation {
    condition     = contains(["sync", "upsert-only", "create-only"], var.external_dns_policy)
    error_message = "external_dns_policy must be one of sync, upsert-only, create-only."
  }
}

# --- cert-manager ------------------------------------------------------------

variable "enable_cert_manager" {
  description = "Install cert-manager (CRDs included). ClusterIssuers are expected to come from GitOps."
  type        = bool
  default     = true
}

variable "cert_manager_hosted_zone_arns" {
  description = "Route 53 hosted zone ARNs cert-manager may use for DNS-01 challenges."
  type        = list(string)
  default     = []
}

# --- KEDA / metrics-server ---------------------------------------------------

variable "enable_keda" {
  description = "Install KEDA for event-driven autoscaling."
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Install metrics-server (required by HPA on CPU/memory)."
  type        = bool
  default     = true
}

# --- Argo CD -----------------------------------------------------------------

variable "enable_argocd" {
  description = "Install Argo CD and bootstrap the app-of-apps root Application."
  type        = bool
  default     = true
}

variable "argocd_ha" {
  description = "Run Argo CD in HA mode (multiple replicas of server, repo-server and application controller sharding friendly settings)."
  type        = bool
  default     = false
}

variable "gitops_repo_url" {
  description = "Git URL of the GitOps repository the root Application points at."
  type        = string
  default     = "https://github.com/ozy31/gitops-multicluster-dr.git"
}

variable "gitops_repo_revision" {
  description = "Branch, tag or commit the root Application tracks."
  type        = string
  default     = "main"
}

variable "gitops_root_path" {
  description = "Path inside the GitOps repo holding this cluster's app-of-apps. Defaults to clusters/<cluster_name>."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to AWS resources created by this module."
  type        = map(string)
  default     = {}
}
