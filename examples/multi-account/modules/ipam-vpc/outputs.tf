output "vpc_id" {
  description = "ID of the IPAM-managed VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block allocated from the IPAM pool."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets."
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_ids" {
  description = "IDs of private subnets."
  value       = aws_subnet.private[*].id
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of private subnets."
  value       = aws_subnet.private[*].cidr_block
}

output "first_public_subnet_cidr" {
  description = "CIDR of the first public subnet (for static host addressing)."
  value       = aws_subnet.public[0].cidr_block
}
