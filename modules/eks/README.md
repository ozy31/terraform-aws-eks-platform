# eks

EKS cluster wrapping [`terraform-aws-modules/eks/aws`](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws) `21.29.0` with opinionated defaults:

- **Access entries only** (`authentication_mode = "API"`), no `aws-auth` ConfigMap. Admin and read-only principals are plain lists of ARNs.
- **Secrets envelope encryption** with a module-managed KMS key, rotation enabled.
- **Private API endpoint** by default; public access is opt-in and CIDR-scoped.
- **Core addons** as EKS managed addons: `vpc-cni` (prefix delegation) and `eks-pod-identity-agent` before compute, then `kube-proxy`, `coredns` and `aws-ebs-csi-driver` (Pod Identity role).
- **System managed node group** labelled `karpenter.sh/controller=true` and tainted `CriticalAddonsOnly`, IMDSv2 with hop limit 1, encrypted gp3, SSM access instead of SSH.
- Node security group tagged for Karpenter discovery. IRSA (OIDC provider) remains enabled for charts that do not support Pod Identity.

## Reference

### Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `cluster_name` | Name of the EKS cluster. | `string` | n/a | yes |
| `kubernetes_version` | Kubernetes minor version for the control plane and the system node group, e.g. "1.34". | `string` | `"1.34"` | no |
| `vpc_id` | ID of the VPC the cluster is deployed into. | `string` | n/a | yes |
| `subnet_ids` | Private subnet IDs for worker nodes (system node group and, via discovery tags, Karpenter nodes). | `list(string)` | n/a | yes |
| `control_plane_subnet_ids` | Subnet IDs for the EKS control plane ENIs. Typically the intra subnets. Defaults to subnet_ids when empty. | `list(string)` | `[]` | no |
| `endpoint_public_access` | Expose the Kubernetes API endpoint publicly. Keep false and reach the API over VPN/TGW where possible. | `bool` | `false` | no |
| `endpoint_public_access_cidrs` | CIDRs allowed to reach the public API endpoint when endpoint_public_access is true. | `list(string)` | `[]` | no |
| `admin_principal_arns` | IAM role/user ARNs granted cluster-admin through EKS access entries (e.g. an SSO admin role and the CI deploy role). | `list(string)` | `[]` | no |
| `readonly_principal_arns` | IAM role/user ARNs granted cluster-wide read-only access through EKS access entries. | `list(string)` | `[]` | no |
| `enable_cluster_creator_admin_permissions` | Grant the identity running Terraform cluster-admin. Handy for bootstrap; prefer explicit admin_principal_arns for long-lived clusters. | `bool` | `false` | no |
| `kms_key_administrators` | IAM ARNs allowed to administer the KMS key used for secrets envelope encryption. Defaults to the caller identity. | `list(string)` | `[]` | no |
| `enabled_log_types` | Control plane log types shipped to CloudWatch. | `list(string)` | `["api", "audit", "authenticator"]` | no |
| `cloudwatch_log_retention_in_days` | Retention for the control plane CloudWatch log group. | `number` | `90` | no |
| `deletion_protection` | Enable EKS cluster deletion protection. Strongly recommended for production clusters. | `bool` | `false` | no |
| `system_node_group` | Managed node group that hosts cluster-critical components (CoreDNS, Karpenter controller, EBS CSI controller). It is tainted with CriticalAddonsOnly so application workloads land on Karpenter-provisioned nodes instead. | `object({...})` | `{}` | no |
| `addon_versions` | Optional pinned versions for EKS managed addons, keyed by addon name. Unpinned addons track the most recent version compatible with the cluster. | `map(string)` | `{}` | no |
| `tags` | Tags applied to every resource created by this module. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|---|---|
| `cluster_name` | Name of the EKS cluster. |
| `cluster_arn` | ARN of the EKS cluster. |
| `cluster_endpoint` | Endpoint of the Kubernetes API server. |
| `cluster_certificate_authority_data` | Base64-encoded certificate authority data for the cluster. |
| `cluster_version` | Kubernetes version of the control plane. |
| `oidc_provider_arn` | ARN of the IAM OIDC provider (for IRSA). |
| `cluster_security_group_id` | ID of the cluster security group. |
| `node_security_group_id` | ID of the shared node security group (tagged for Karpenter discovery). |
| `kms_key_arn` | ARN of the KMS key used for Kubernetes Secrets encryption. |
| `system_node_group_iam_role_arn` | IAM role ARN of the system managed node group. |
