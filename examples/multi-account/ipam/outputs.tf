output "ipam_id" {
  description = "ID of the created IPAM instance."
  value       = module.ipam.ipam_id
}

output "operating_regions" {
  description = "AWS regions where IPAM manages CIDRs (home + pool locales)."
  value       = distinct([var.primary_region, var.secondary_region])
}

output "nz_dev_pool_id" {
  description = "IPAM pool ID for org/nz/dev, RAM-shared with workload account A (dev, ap-southeast-6)."
  value       = module.ipam.pool_ids["org/nz/dev"]
}

output "au_sandbox_pool_id" {
  description = "IPAM pool ID for org/au/sandbox, RAM-shared with workload account B (sandbox, ap-southeast-2)."
  value       = module.ipam.pool_ids["org/au/sandbox"]
}

output "ram_share_pool_keys" {
  description = "Pool path keys with RAM shares configured."
  value       = module.ipam.ram_share_pool_keys
}
