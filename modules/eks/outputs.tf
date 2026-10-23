output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_version" {
  description = "Kubernetes version of the control plane."
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider (for IRSA)."
  value       = module.eks.oidc_provider_arn
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group."
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "ID of the shared node security group (tagged for Karpenter discovery)."
  value       = module.eks.node_security_group_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for Kubernetes Secrets encryption."
  value       = module.eks.kms_key_arn
}

output "system_node_group_iam_role_arn" {
  description = "IAM role ARN of the system managed node group."
  value       = module.eks.eks_managed_node_groups["system"].iam_role_arn
}
