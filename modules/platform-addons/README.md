# platform-addons

The minimum set of cluster addons a workload cluster needs before GitOps takes over. Every addon is toggleable and every chart version is pinned in one `chart_versions` object.

| Addon | Namespace | AWS access |
|---|---|---|
| AWS Load Balancer Controller | kube-system | Pod Identity role (`attach_aws_lb_controller_policy`) |
| external-dns | external-dns | Pod Identity role scoped to `external_dns_hosted_zone_arns` |
| cert-manager (CRDs included) | cert-manager | Pod Identity role scoped to `cert_manager_hosted_zone_arns` (DNS-01) |
| metrics-server | kube-system | none |
| KEDA | keda | none at operator level |
| Argo CD + root Application | argocd | none |

IAM roles come from [`terraform-aws-modules/eks-pod-identity/aws`](https://registry.terraform.io/modules/terraform-aws-modules/eks-pod-identity/aws) `2.10.0`.

**Argo CD bootstrap.** Terraform installs Argo CD and exactly one `Application` (via the `argocd-apps` chart) pointing at `gitops_repo_url` / `gitops_root_path` (default `clusters/<cluster_name>`). Everything else - ClusterIssuers, ingress classes, observability, workloads - is owned by the GitOps repo. Terraform does not manage anything Argo CD manages.

**external-dns** defaults to `upsert-only` with `txtOwnerId = cluster_name`, so a primary and a DR cluster sharing a zone never overwrite or delete each other's records.

Requires a configured `helm` provider pointing at the cluster.

## Reference

### Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `cluster_name` | Name of the EKS cluster. | `string` | n/a | yes |
| `vpc_id` | VPC ID of the cluster. Passed explicitly to the AWS Load Balancer Controller because nodes block IMDS from pods. | `string` | n/a | yes |
| `chart_versions` | Pinned Helm chart versions. Override individual keys to upgrade a single addon. | `object({...})` | `{}` | no |
| `enable_aws_load_balancer_controller` | Install the AWS Load Balancer Controller. | `bool` | `true` | no |
| `enable_external_dns` | Install external-dns for Route 53. | `bool` | `true` | no |
| `external_dns_hosted_zone_arns` | Route 53 hosted zone ARNs external-dns may modify. The IAM policy is scoped to exactly these zones. | `list(string)` | `[]` | no |
| `external_dns_domain_filters` | Domains external-dns is allowed to manage records for. | `list(string)` | `[]` | no |
| `external_dns_policy` | external-dns sync policy. "upsert-only" never deletes records, which is the safer default when two clusters (primary and DR) share a zone. | `string` | `"upsert-only"` | no |
| `enable_cert_manager` | Install cert-manager (CRDs included). ClusterIssuers are expected to come from GitOps. | `bool` | `true` | no |
| `cert_manager_hosted_zone_arns` | Route 53 hosted zone ARNs cert-manager may use for DNS-01 challenges. | `list(string)` | `[]` | no |
| `enable_keda` | Install KEDA for event-driven autoscaling. | `bool` | `true` | no |
| `enable_metrics_server` | Install metrics-server (required by HPA on CPU/memory). | `bool` | `true` | no |
| `enable_argocd` | Install Argo CD and bootstrap the app-of-apps root Application. | `bool` | `true` | no |
| `argocd_ha` | Run Argo CD in HA mode (multiple replicas of server, repo-server and application controller sharding friendly settings). | `bool` | `false` | no |
| `gitops_repo_url` | Git URL of the GitOps repository the root Application points at. | `string` | `"https://github.com/ozy31/gitops-multicluster-dr.git"` | no |
| `gitops_repo_revision` | Branch, tag or commit the root Application tracks. | `string` | `"main"` | no |
| `gitops_root_path` | Path inside the GitOps repo holding this cluster's app-of-apps. Defaults to clusters/<cluster_name>. | `string` | `null` | no |
| `tags` | Tags applied to AWS resources created by this module. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|---|---|
| `argocd_namespace` | Namespace Argo CD is installed in (null when disabled). |
| `gitops_root_path` | Path in the GitOps repository the root Application syncs. |
| `aws_load_balancer_controller_role_arn` | IAM role ARN used by the AWS Load Balancer Controller. |
| `external_dns_role_arn` | IAM role ARN used by external-dns. |
| `cert_manager_role_arn` | IAM role ARN used by cert-manager. |
| `installed_charts` | Map of installed Helm releases to their chart versions. |
