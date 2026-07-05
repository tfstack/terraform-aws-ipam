variable "primary_region" {
  description = "IPAM home region and locale for NZ pools (ap-southeast-6)."
  type        = string
  default     = "ap-southeast-6"
}

variable "secondary_region" {
  description = "Locale for AU pools (ap-southeast-2)."
  type        = string
  default     = "ap-southeast-2"
}

variable "workload_account_a_id" {
  description = "12-digit AWS account ID for workload A (RAM principal for org/nz/dev pool)."
  type        = string
}

variable "workload_account_b_id" {
  description = "12-digit AWS account ID for workload B (RAM principal for org/au/sandbox pool)."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Example = "multi-account"
  }
}
