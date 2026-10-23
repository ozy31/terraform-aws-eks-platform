# complete

All four modules wired together in plain Terraform: VPC, EKS, Karpenter (Bottlerocket,
spot + on-demand) and the platform addons with Argo CD bootstrapped against
[`gitops-multicluster-dr`](https://github.com/ozy31/gitops-multicluster-dr).

Differences from the `live/` environments, to keep the example cheap and self-contained:

- one shared NAT gateway
- burstable system nodes and a 64 vCPU Karpenter limit
- external-dns disabled (no hosted zone required)
- local state

```bash
terraform init
terraform plan  -var 'api_allowed_cidrs=["203.0.113.10/32"]'
terraform apply -var 'api_allowed_cidrs=["203.0.113.10/32"]'

aws eks update-kubeconfig --region eu-west-1 --name platform-example
```

Leaving `api_allowed_cidrs` empty keeps the API endpoint private; you then need to run
Terraform from inside the VPC (or over VPN) for the Helm releases to apply.

To tear down, delete the Argo CD root Application and wait for load balancers to be
removed, then `terraform destroy`.

This creates billable resources (EKS control plane, NAT gateway, EC2 instances).
