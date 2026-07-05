provider "aws" {
  region = var.primary_region

  default_tags {
    tags = var.tags
  }
}

module "ipam" {
  source = "../../.."

  pools = {
    org = {
      cidr        = ["10.0.0.0/8"]
      description = "Org-wide super-pool (global container)"
      # No locale on the root pool — AWS requires child locale to match the parent
      # when the parent has a locale set. Regional locales belong on org/nz and org/au.

      sub_pools = {
        nz = {
          cidr        = ["10.64.0.0/12"]
          locale      = var.primary_region
          description = "NZ regional aggregate (ap-southeast-6)"

          sub_pools = {
            dev = {
              cidr                              = ["10.64.0.0/16"]
              locale                            = var.primary_region
              allocation_default_netmask_length = 20
              description                       = "NZ dev pool (ap-southeast-6)"
              # RAM principal = permission to use pool in workload account (not IPAM allocation)
              ram_share_principals = [var.workload_account_a_id]
            }
          }
        }
        au = {
          cidr        = ["10.128.0.0/12"]
          locale      = var.secondary_region
          description = "AU regional aggregate (ap-southeast-2)"

          sub_pools = {
            sandbox = {
              cidr                              = ["10.128.0.0/16"]
              locale                            = var.secondary_region
              allocation_default_netmask_length = 20
              description                       = "AU sandbox pool (ap-southeast-2)"
              # RAM principal = permission to use pool in workload account (not IPAM allocation)
              ram_share_principals = [var.workload_account_b_id]
            }
          }
        }
      }
    }
  }

  tags = var.tags
}
