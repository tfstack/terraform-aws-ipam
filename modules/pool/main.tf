locals {
  l1_pools = {
    for k, v in var.flat_pools : k => v
    if !strcontains(k, "/")
  }

  l2_pools = {
    for k, v in var.flat_pools : k => v
    if length(split("/", k)) == 2
  }

  l3_pools = {
    for k, v in var.flat_pools : k => v
    if length(split("/", k)) == 3
  }

  l4_pools = {
    for k, v in var.flat_pools : k => v
    if length(split("/", k)) == 4
  }

  l5_pools = {
    for k, v in var.flat_pools : k => v
    if length(split("/", k)) == 5
  }
}

resource "aws_vpc_ipam_pool" "l1" {
  for_each = var.create ? local.l1_pools : {}

  address_family                    = var.address_family
  ipam_scope_id                     = var.ipam_scope_id
  source_ipam_pool_id               = null
  locale                            = each.value.locale != null ? each.value.locale : try(each.value.implied_locale, null)
  description                       = try(each.value.description, null)
  allocation_default_netmask_length = try(each.value.allocation_default_netmask_length, null)
  allocation_min_netmask_length     = try(each.value.allocation_min_netmask_length, null)
  allocation_max_netmask_length     = try(each.value.allocation_max_netmask_length, null)
  allocation_resource_tags          = try(each.value.allocation_resource_tags, null)
  auto_import                       = try(each.value.auto_import, null)

  tags = var.tags
}

resource "aws_vpc_ipam_pool" "l2" {
  for_each = var.create ? local.l2_pools : {}

  address_family                    = var.address_family
  ipam_scope_id                     = var.ipam_scope_id
  source_ipam_pool_id               = aws_vpc_ipam_pool.l1[each.value.parent_key].id
  locale                            = each.value.locale != null ? each.value.locale : try(each.value.implied_locale, null)
  description                       = try(each.value.description, null)
  allocation_default_netmask_length = try(each.value.allocation_default_netmask_length, null)
  allocation_min_netmask_length     = try(each.value.allocation_min_netmask_length, null)
  allocation_max_netmask_length     = try(each.value.allocation_max_netmask_length, null)
  allocation_resource_tags          = try(each.value.allocation_resource_tags, null)
  auto_import                       = try(each.value.auto_import, null)

  tags = var.tags
}

resource "aws_vpc_ipam_pool" "l3" {
  for_each = var.create ? local.l3_pools : {}

  address_family                    = var.address_family
  ipam_scope_id                     = var.ipam_scope_id
  source_ipam_pool_id               = aws_vpc_ipam_pool.l2[each.value.parent_key].id
  locale                            = each.value.locale != null ? each.value.locale : try(each.value.implied_locale, null)
  description                       = try(each.value.description, null)
  allocation_default_netmask_length = try(each.value.allocation_default_netmask_length, null)
  allocation_min_netmask_length     = try(each.value.allocation_min_netmask_length, null)
  allocation_max_netmask_length     = try(each.value.allocation_max_netmask_length, null)
  allocation_resource_tags          = try(each.value.allocation_resource_tags, null)
  auto_import                       = try(each.value.auto_import, null)

  tags = var.tags
}

resource "aws_vpc_ipam_pool" "l4" {
  for_each = var.create ? local.l4_pools : {}

  address_family                    = var.address_family
  ipam_scope_id                     = var.ipam_scope_id
  source_ipam_pool_id               = aws_vpc_ipam_pool.l3[each.value.parent_key].id
  locale                            = each.value.locale != null ? each.value.locale : try(each.value.implied_locale, null)
  description                       = try(each.value.description, null)
  allocation_default_netmask_length = try(each.value.allocation_default_netmask_length, null)
  allocation_min_netmask_length     = try(each.value.allocation_min_netmask_length, null)
  allocation_max_netmask_length     = try(each.value.allocation_max_netmask_length, null)
  allocation_resource_tags          = try(each.value.allocation_resource_tags, null)
  auto_import                       = try(each.value.auto_import, null)

  tags = var.tags
}

resource "aws_vpc_ipam_pool" "l5" {
  for_each = var.create ? local.l5_pools : {}

  address_family                    = var.address_family
  ipam_scope_id                     = var.ipam_scope_id
  source_ipam_pool_id               = aws_vpc_ipam_pool.l4[each.value.parent_key].id
  locale                            = each.value.locale != null ? each.value.locale : try(each.value.implied_locale, null)
  description                       = try(each.value.description, null)
  allocation_default_netmask_length = try(each.value.allocation_default_netmask_length, null)
  allocation_min_netmask_length     = try(each.value.allocation_min_netmask_length, null)
  allocation_max_netmask_length     = try(each.value.allocation_max_netmask_length, null)
  allocation_resource_tags          = try(each.value.allocation_resource_tags, null)
  auto_import                       = try(each.value.auto_import, null)

  tags = var.tags
}

locals {
  pools = merge(
    aws_vpc_ipam_pool.l1,
    aws_vpc_ipam_pool.l2,
    aws_vpc_ipam_pool.l3,
    aws_vpc_ipam_pool.l4,
    aws_vpc_ipam_pool.l5,
  )
}

resource "aws_vpc_ipam_pool_cidr" "this" {
  for_each = var.create ? merge([
    for pool_key, pool in var.flat_pools : {
      for cidr in pool.cidr : "${pool_key}/${cidr}" => {
        pool_key = pool_key
        cidr     = cidr
      }
    }
  ]...) : {}

  ipam_pool_id = local.pools[each.value.pool_key].id
  cidr         = each.value.cidr
}

resource "aws_ram_resource_share" "this" {
  for_each = var.create ? {
    for k, v in var.flat_pools : k => v
    if length(coalesce(v.ram_share_principals, [])) > 0
  } : {}

  name = replace(each.key, "/", "-")

  tags = var.tags
}

resource "aws_ram_resource_association" "this" {
  for_each = aws_ram_resource_share.this

  resource_arn       = local.pools[each.key].arn
  resource_share_arn = aws_ram_resource_share.this[each.key].arn
}

resource "aws_ram_principal_association" "this" {
  for_each = var.create ? merge([
    for pool_key, pool in var.flat_pools : {
      for principal in coalesce(pool.ram_share_principals, []) : "${pool_key}/${principal}" => {
        pool_key  = pool_key
        principal = principal
      }
    } if length(coalesce(pool.ram_share_principals, [])) > 0
  ]...) : {}

  principal          = each.value.principal
  resource_share_arn = aws_ram_resource_share.this[each.value.pool_key].arn
}
