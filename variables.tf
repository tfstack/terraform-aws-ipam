variable "create" {
  description = "Whether to create IPAM and pool resources."
  type        = bool
  default     = true
}

variable "create_ipam" {
  description = "Whether to create a new IPAM instance. When false, provide ipam_scope_id."
  type        = bool
  default     = true
}

variable "ipam_scope_id" {
  description = "Existing IPAM scope ID to attach pools to when create_ipam is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_ipam || !var.create || var.ipam_scope_id != null
    error_message = "ipam_scope_id must be provided when create_ipam is false and create is true."
  }
}

variable "scope_type" {
  description = "IPAM scope type to use when creating a new IPAM instance."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public"], var.scope_type)
    error_message = "scope_type must be \"private\" or \"public\"."
  }
}

variable "address_family" {
  description = "Address family applied to all pools."
  type        = string
  default     = "ipv4"
}

variable "description" {
  description = "Description of the IPAM instance."
  type        = string
  default     = null
}

variable "pools" {
  description = "Nested pool definitions. Max depth 5."
  type = map(object({
    cidr                              = list(string)
    locale                            = optional(string)
    description                       = optional(string)
    allocation_default_netmask_length = optional(number)
    allocation_min_netmask_length     = optional(number)
    allocation_max_netmask_length     = optional(number)
    allocation_resource_tags          = optional(map(string))
    auto_import                       = optional(bool)
    ram_share_principals              = optional(list(string))
    sub_pools = optional(map(object({
      cidr                              = list(string)
      locale                            = optional(string)
      description                       = optional(string)
      allocation_default_netmask_length = optional(number)
      allocation_min_netmask_length     = optional(number)
      allocation_max_netmask_length     = optional(number)
      allocation_resource_tags          = optional(map(string))
      auto_import                       = optional(bool)
      ram_share_principals              = optional(list(string))
      sub_pools = optional(map(object({
        cidr                              = list(string)
        locale                            = optional(string)
        description                       = optional(string)
        allocation_default_netmask_length = optional(number)
        allocation_min_netmask_length     = optional(number)
        allocation_max_netmask_length     = optional(number)
        allocation_resource_tags          = optional(map(string))
        auto_import                       = optional(bool)
        ram_share_principals              = optional(list(string))
        sub_pools = optional(map(object({
          cidr                              = list(string)
          locale                            = optional(string)
          description                       = optional(string)
          allocation_default_netmask_length = optional(number)
          allocation_min_netmask_length     = optional(number)
          allocation_max_netmask_length     = optional(number)
          allocation_resource_tags          = optional(map(string))
          auto_import                       = optional(bool)
          ram_share_principals              = optional(list(string))
          sub_pools = optional(map(object({
            cidr                              = list(string)
            locale                            = optional(string)
            description                       = optional(string)
            allocation_default_netmask_length = optional(number)
            allocation_min_netmask_length     = optional(number)
            allocation_max_netmask_length     = optional(number)
            allocation_resource_tags          = optional(map(string))
            auto_import                       = optional(bool)
            ram_share_principals              = optional(list(string))
            sub_pools = optional(map(object({
              cidr                              = list(string)
              locale                            = optional(string)
              description                       = optional(string)
              allocation_default_netmask_length = optional(number)
              allocation_min_netmask_length     = optional(number)
              allocation_max_netmask_length     = optional(number)
              allocation_resource_tags          = optional(map(string))
              auto_import                       = optional(bool)
              ram_share_principals              = optional(list(string))
            })))
          })))
        })))
      })))
    })))
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for k1, v1 in var.pools : concat(
        [!strcontains(k1, "/")],
        flatten([
          for k2, v2 in coalesce(v1.sub_pools, {}) : concat(
            [!strcontains(k2, "/")],
            flatten([
              for k3, v3 in coalesce(v2.sub_pools, {}) : concat(
                [!strcontains(k3, "/")],
                flatten([
                  for k4, v4 in coalesce(v3.sub_pools, {}) : concat(
                    [!strcontains(k4, "/")],
                    [for k5, v5 in coalesce(v4.sub_pools, {}) : !strcontains(k5, "/")]
                  )
                ])
              )
            ])
          )
        ])
      )
    ]))
    error_message = "Pool keys must not contain '/' (reserved as path separator)."
  }
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
