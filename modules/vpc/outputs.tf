output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "azs" {
  description = "Availability zones the subnets were created in."
  value       = local.azs
}

output "private_subnet_ids" {
  description = "Private subnet IDs (worker nodes and pods)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (NAT gateways and internet-facing load balancers)."
  value       = module.vpc.public_subnets
}

output "intra_subnet_ids" {
  description = "Intra subnet IDs without internet routes (EKS control plane ENIs)."
  value       = module.vpc.intra_subnets
}

output "nat_public_ips" {
  description = "Elastic IPs of the NAT gateways. Useful for allow-listing egress at third parties."
  value       = module.vpc.nat_public_ips
}
