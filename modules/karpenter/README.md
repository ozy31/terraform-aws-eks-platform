# karpenter

Karpenter controller plus a default `EC2NodeClass` and `NodePool`.

- IAM via [`terraform-aws-modules/eks/aws//modules/karpenter`](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter) `21.29.0`: controller role bound with **EKS Pod Identity**, node role + access entry, SQS queue and EventBridge rules for spot interruption / rebalance / health events.
- Controller installed from `oci://public.ecr.aws/karpenter/karpenter`, pinned to the system node group and resolving DNS through the VPC resolver so it can come up before CoreDNS has capacity.
- `EC2NodeClass` and `NodePool` ship as a small local chart (`charts/karpenter-resources`), so `terraform plan` works before the Karpenter CRDs exist (unlike `kubernetes_manifest`).
- `node_os = "bottlerocket"` switches the AMI alias and block device layout (4 GiB OS volume + data volume); default is AL2023.
- Default pool allows `spot` and `on-demand` (Karpenter picks spot first, falls back to on-demand), c/m/r families newer than generation 5, `WhenEmptyOrUnderutilized` consolidation, 30-day node expiry and a 10% disruption budget.

Requires a configured `helm` provider pointing at the cluster.

## Reference

### Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `cluster_name` | Name of the EKS cluster Karpenter manages. | `string` | n/a | yes |
| `cluster_endpoint` | Kubernetes API endpoint of the cluster. Passed to Karpenter to avoid an extra DescribeCluster call. | `string` | n/a | yes |
| `karpenter_version` | Karpenter Helm chart version (OCI chart at public.ecr.aws/karpenter/karpenter). | `string` | `"1.15.0"` | no |
| `namespace` | Namespace the Karpenter controller runs in. | `string` | `"kube-system"` | no |
| `controller_replicas` | Number of Karpenter controller replicas (leader-elected). | `number` | `2` | no |
| `node_os` | Operating system for Karpenter-provisioned nodes: "al2023" or "bottlerocket". | `string` | `"al2023"` | no |
| `ami_alias_version` | AMI alias version for the EC2NodeClass (e.g. "latest" or a pinned "v20250715"). Pin in production and roll forward deliberately. | `string` | `"latest"` | no |
| `node_volume_size_gib` | Size of the node data volume (root volume on AL2023, data volume on Bottlerocket). | `number` | `50` | no |
| `capacity_types` | Capacity types the default NodePool may launch. With both, Karpenter prefers spot and falls back to on-demand. | `list(string)` | `["spot", "on-demand"]` | no |
| `architectures` | CPU architectures allowed in the default NodePool. | `list(string)` | `["amd64"]` | no |
| `instance_categories` | EC2 instance categories allowed in the default NodePool. A wide set gives the spot allocator more pools to choose from. | `list(string)` | `["c", "m", "r"]` | no |
| `instance_generation_greater_than` | Only allow instance generations strictly greater than this value. | `number` | `5` | no |
| `cpu_limit` | Upper bound of total vCPU the default NodePool may provision. Acts as a cost circuit breaker. | `number` | `1000` | no |
| `memory_limit` | Upper bound of total memory the default NodePool may provision (Kubernetes quantity). | `string` | `"4000Gi"` | no |
| `consolidation_policy` | Karpenter consolidation policy: WhenEmptyOrUnderutilized or WhenEmpty. | `string` | `"WhenEmptyOrUnderutilized"` | no |
| `consolidate_after` | How long a node must be consolidatable before Karpenter acts on it. | `string` | `"1m"` | no |
| `expire_after` | Maximum node lifetime; forces regular node rotation onto fresh AMIs. | `string` | `"720h"` | no |
| `disruption_budgets` | Karpenter disruption budgets for the default NodePool. | `list(object({...})` | `[{ nodes = "10%" }]` | no |
| `tags` | Tags applied to AWS resources created by this module and to every EC2 instance Karpenter launches. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|---|---|
| `controller_iam_role_arn` | IAM role ARN assumed by the Karpenter controller through EKS Pod Identity. |
| `node_iam_role_name` | IAM role name used by Karpenter-provisioned nodes. |
| `node_iam_role_arn` | IAM role ARN used by Karpenter-provisioned nodes. |
| `interruption_queue_name` | Name of the SQS queue receiving EC2 interruption events. |
| `karpenter_version` | Deployed Karpenter chart version. |
