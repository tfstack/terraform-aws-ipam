output "ipam_id" {
  description = "ID of the created IPAM instance."
  value       = module.ipam.ipam_id
}

output "pool_id" {
  description = "ID of the workload pool."
  value       = module.ipam.pool_ids["workload"]
}

output "previewed_vpc_cidr" {
  description = "CIDR previewed from the IPAM pool for the VPC."
  value       = aws_vpc_ipam_preview_next_cidr.vpc.cidr
}

output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the created VPC."
  value       = module.vpc.vpc_cidr
}
