output "vpc_id" {
  description = "ID of the IPAM-managed VPC."
  value       = module.ipam_vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block allocated from the IPAM pool."
  value       = module.ipam_vpc.vpc_cidr
}

output "demo_instance_id" {
  description = "ID of the demo EC2 instance."
  value       = aws_instance.demo.id
}

output "demo_private_ip" {
  description = "Static private IP of the demo EC2 instance (host .5 in first public subnet)."
  value       = aws_instance.demo.private_ip
}
