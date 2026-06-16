data "aws_region" "current" {}

locals {
  l1_pools = {
    for k, v in var.pools : k => merge(v, {
      parent_key     = null
      implied_locale = try(v.locale, null)
    })
  }

  l2_pools = merge([
    for k1, v1 in var.pools : {
      for k2, v2 in coalesce(v1.sub_pools, {}) : "${k1}/${k2}" => merge(v2, {
        parent_key = k1
        implied_locale = v2.locale != null ? v2.locale : (
          v1.locale != null ? v1.locale : null
        )
      })
    }
  ]...)

  l3_pools = merge([
    for k1, v1 in var.pools : merge([
      for k2, v2 in coalesce(v1.sub_pools, {}) : {
        for k3, v3 in coalesce(v2.sub_pools, {}) : "${k1}/${k2}/${k3}" => merge(v3, {
          parent_key = "${k1}/${k2}"
          implied_locale = v3.locale != null ? v3.locale : (
            v2.locale != null ? v2.locale : (
              v1.locale != null ? v1.locale : null
            )
          )
        })
      }
    ]...)
  ]...)

  l4_pools = merge([
    for k1, v1 in var.pools : merge([
      for k2, v2 in coalesce(v1.sub_pools, {}) : merge([
        for k3, v3 in coalesce(v2.sub_pools, {}) : {
          for k4, v4 in coalesce(v3.sub_pools, {}) : "${k1}/${k2}/${k3}/${k4}" => merge(v4, {
            parent_key = "${k1}/${k2}/${k3}"
            implied_locale = v4.locale != null ? v4.locale : (
              v3.locale != null ? v3.locale : (
                v2.locale != null ? v2.locale : (
                  v1.locale != null ? v1.locale : null
                )
              )
            )
          })
        }
      ]...)
    ]...)
  ]...)

  l5_pools = merge([
    for k1, v1 in var.pools : merge([
      for k2, v2 in coalesce(v1.sub_pools, {}) : merge([
        for k3, v3 in coalesce(v2.sub_pools, {}) : merge([
          for k4, v4 in coalesce(v3.sub_pools, {}) : {
            for k5, v5 in coalesce(v4.sub_pools, {}) : "${k1}/${k2}/${k3}/${k4}/${k5}" => merge(v5, {
              parent_key = "${k1}/${k2}/${k3}/${k4}"
              implied_locale = v5.locale != null ? v5.locale : (
                v4.locale != null ? v4.locale : (
                  v3.locale != null ? v3.locale : (
                    v2.locale != null ? v2.locale : (
                      v1.locale != null ? v1.locale : null
                    )
                  )
                )
              )
            })
          }
        ]...)
      ]...)
    ]...)
  ]...)

  flat_pools = merge(
    local.l1_pools,
    local.l2_pools,
    local.l3_pools,
    local.l4_pools,
    local.l5_pools,
  )

  operating_regions = distinct(concat(
    [data.aws_region.current.region],
    [for k, v in local.flat_pools : v.locale if v.locale != null]
  ))

  scope_id = var.create && var.create_ipam ? (
    var.scope_type == "private"
    ? module.ipam_core[0].private_default_scope_id
    : module.ipam_core[0].public_default_scope_id
  ) : var.ipam_scope_id
}

module "ipam_core" {
  source = "./modules/ipam-core"
  count  = var.create && var.create_ipam ? 1 : 0

  operating_regions = local.operating_regions
  description       = var.description
  tags              = var.tags
}

module "pool" {
  source = "./modules/pool"
  count  = var.create ? 1 : 0

  address_family = var.address_family
  ipam_scope_id  = local.scope_id
  flat_pools     = local.flat_pools
  tags           = var.tags

  depends_on = [module.ipam_core]
}
