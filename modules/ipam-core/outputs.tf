output "id" {
  description = "ID of the IPAM instance."
  value       = var.create ? aws_vpc_ipam.this[0].id : null
}

output "arn" {
  description = "ARN of the IPAM instance."
  value       = var.create ? aws_vpc_ipam.this[0].arn : null
}

output "private_default_scope_id" {
  description = "Default private scope ID of the IPAM instance."
  value       = var.create ? aws_vpc_ipam.this[0].private_default_scope_id : null
}

output "public_default_scope_id" {
  description = "Default public scope ID of the IPAM instance."
  value       = var.create ? aws_vpc_ipam.this[0].public_default_scope_id : null
}
