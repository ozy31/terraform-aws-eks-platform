# vpc

Three-AZ VPC for EKS, wrapping [`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) `6.7.3`.

- Private `/19` subnets per AZ for nodes and pods (VPC CNI with prefix delegation is IP-hungry), public `/24` subnets for NAT and internet-facing load balancers, intra `/24` subnets with no internet route for EKS control-plane ENIs.
- NAT gateway per AZ by default; `single_nat_gateway = true` for non-production.
- Subnet tags for the AWS Load Balancer Controller (`kubernetes.io/role/elb`, `kubernetes.io/role/internal-elb`) and Karpenter discovery (`karpenter.sh/discovery`).
- Default security group stripped of all rules; VPC flow logs to CloudWatch.

| Tier | Prefix | Example for `10.30.0.0/16` |
|---|---|---|
| private | /19 x3 | 10.30.0.0/19, 10.30.32.0/19, 10.30.64.0/19 |
| public | /24 x3 | 10.30.96.0/24 - 10.30.98.0/24 |
| intra | /24 x3 | 10.30.104.0/24 - 10.30.106.0/24 |

## Reference

### Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `name` | Name prefix for the VPC and all of its child resources. | `string` | n/a | yes |
| `cidr` | IPv4 CIDR block for the VPC. Must be a /16; subnets are carved out of it deterministically (see README). | `string` | `"10.0.0.0/16"` | no |
| `azs` | Availability zones to spread subnets across. Defaults to the first three AZs of the current region. | `list(string)` | `null` | no |
| `cluster_name` | Name of the EKS cluster that will live in this VPC. Used for Karpenter discovery and load balancer subnet tags. | `string` | n/a | yes |
| `single_nat_gateway` | Use one shared NAT gateway instead of one per AZ. Cheaper, but an AZ outage takes down egress for the whole VPC. Recommended only for non-production. | `bool` | `false` | no |
| `enable_flow_logs` | Ship VPC flow logs to a dedicated CloudWatch log group. | `bool` | `true` | no |
| `flow_logs_retention_in_days` | Retention for the VPC flow log CloudWatch log group. | `number` | `30` | no |
| `tags` | Tags applied to every resource created by this module. | `map(string)` | `{}` | no |

### Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC. |
| `vpc_cidr_block` | CIDR block of the VPC. |
| `azs` | Availability zones the subnets were created in. |
| `private_subnet_ids` | Private subnet IDs (worker nodes and pods). |
| `public_subnet_ids` | Public subnet IDs (NAT gateways and internet-facing load balancers). |
| `intra_subnet_ids` | Intra subnet IDs without internet routes (EKS control plane ENIs). |
| `nat_public_ips` | Elastic IPs of the NAT gateways. Useful for allow-listing egress at third parties. |
