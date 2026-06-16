output "pools" {
  description = "Map of pool attributes keyed by path."
  value = var.create ? {
    for k, p in local.pools : k => {
      id     = p.id
      arn    = p.arn
      locale = p.locale
      cidr = [
        for cidr_key, cidr in aws_vpc_ipam_pool_cidr.this : cidr.cidr
        if startswith(cidr_key, "${k}/")
      ]
      source_ipam_pool_id = p.source_ipam_pool_id
    }
  } : {}
}

output "pool_ids" {
  description = "Map of pool IDs keyed by path."
  value       = var.create ? { for k, p in local.pools : k => p.id } : {}
}

output "ram_share_pool_keys" {
  description = "Pool keys with RAM shares configured."
  value       = var.create ? keys(aws_ram_resource_share.this) : []
}
