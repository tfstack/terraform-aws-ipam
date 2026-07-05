output "ipam_admin_account_id" {
  description = "Delegated IPAM admin account ID."
  value       = aws_vpc_ipam_organization_admin_account.ipam_admin.id
}

output "ipam_admin_account_arn" {
  description = "Delegated IPAM admin account ARN."
  value       = aws_vpc_ipam_organization_admin_account.ipam_admin.arn
}
