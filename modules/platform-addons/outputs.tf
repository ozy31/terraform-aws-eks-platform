output "argocd_namespace" {
  description = "Namespace Argo CD is installed in (null when disabled)."
  value       = var.enable_argocd ? helm_release.argocd[0].namespace : null
}

output "gitops_root_path" {
  description = "Path in the GitOps repository the root Application syncs."
  value       = local.gitops_root_path
}

output "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN used by the AWS Load Balancer Controller."
  value       = try(module.aws_lb_controller_pod_identity[0].iam_role_arn, null)
}

output "external_dns_role_arn" {
  description = "IAM role ARN used by external-dns."
  value       = try(module.external_dns_pod_identity[0].iam_role_arn, null)
}

output "cert_manager_role_arn" {
  description = "IAM role ARN used by cert-manager."
  value       = try(module.cert_manager_pod_identity[0].iam_role_arn, null)
}

output "installed_charts" {
  description = "Map of installed Helm releases to their chart versions."
  value = merge(
    { for r in helm_release.aws_load_balancer_controller : r.name => r.version },
    { for r in helm_release.external_dns : r.name => r.version },
    { for r in helm_release.cert_manager : r.name => r.version },
    { for r in helm_release.metrics_server : r.name => r.version },
    { for r in helm_release.keda : r.name => r.version },
    { for r in helm_release.argocd : r.name => r.version },
  )
}
