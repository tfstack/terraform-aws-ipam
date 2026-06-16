variable "create" {
  description = "Whether to create pool resources."
  type        = bool
  default     = true
}

variable "address_family" {
  description = "Address family for all pools."
  type        = string
  default     = "ipv4"
}

variable "ipam_scope_id" {
  description = "IPAM scope ID to attach pools to."
  type        = string
}

variable "flat_pools" {
  description = "Flattened pool definitions keyed by path."
  type = map(object({
    cidr                              = list(string)
    locale                            = optional(string)
    implied_locale                    = optional(string)
    description                       = optional(string)
    allocation_default_netmask_length = optional(number)
    allocation_min_netmask_length     = optional(number)
    allocation_max_netmask_length     = optional(number)
    allocation_resource_tags          = optional(map(string))
    auto_import                       = optional(bool)
    ram_share_principals              = optional(list(string))
    parent_key                        = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to pool resources."
  type        = map(string)
  default     = {}
}
