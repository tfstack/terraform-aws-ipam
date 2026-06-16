variable "create" {
  description = "Whether to create the IPAM instance."
  type        = bool
  default     = true
}

variable "operating_regions" {
  description = "AWS regions where the IPAM operates."
  type        = list(string)
}

variable "description" {
  description = "Description of the IPAM instance."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the IPAM instance."
  type        = map(string)
  default     = {}
}
