variable "region" {
  description = "AWS region for the provider (IPAM org admin is a global Organizations action)."
  type        = string
  default     = "ap-southeast-6"
}

variable "ipam_admin_account_id" {
  description = "12-digit member account ID to delegate as IPAM admin (cannot be the management account)."
  type        = string
}

variable "ram_sharing_enable_wait_duration" {
  description = "Wait after enabling RAM org sharing before member accounts create shares."
  type        = string
  default     = "180s"
}

variable "tags" {
  description = "Default tags applied to all resources."
  type        = map(string)
  default = {
    Example = "multi-account"
  }
}
