output "ipam_id" {
  description = "ID of the created IPAM instance."
  value       = try(module.ipam_core[0].id, null)
}

output "ipam_arn" {
  description = "ARN of the created IPAM instance."
  value       = try(module.ipam_core[0].arn, null)
}

output "private_scope_id" {
  description = "Private default scope ID of the created IPAM instance."
  value       = try(module.ipam_core[0].private_default_scope_id, null)
}

output "pools" {
  description = "Map of pool attributes keyed by path."
  value       = try(module.pool[0].pools, {})
}

output "pool_ids" {
  description = "Map of pool IDs keyed by path."
  value       = try(module.pool[0].pool_ids, {})
}

output "ram_share_pool_keys" {
  description = "Pool keys with RAM shares configured."
  value       = try(module.pool[0].ram_share_pool_keys, [])
}
