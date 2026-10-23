output "controller_iam_role_arn" {
  description = "IAM role ARN assumed by the Karpenter controller through EKS Pod Identity."
  value       = module.karpenter.iam_role_arn
}

output "node_iam_role_name" {
  description = "IAM role name used by Karpenter-provisioned nodes."
  value       = module.karpenter.node_iam_role_name
}

output "node_iam_role_arn" {
  description = "IAM role ARN used by Karpenter-provisioned nodes."
  value       = module.karpenter.node_iam_role_arn
}

output "interruption_queue_name" {
  description = "Name of the SQS queue receiving EC2 interruption events."
  value       = module.karpenter.queue_name
}

output "karpenter_version" {
  description = "Deployed Karpenter chart version."
  value       = helm_release.karpenter.version
}
