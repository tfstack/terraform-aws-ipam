variable "region" {
  description = "AWS region for the workload VPC (ap-southeast-6 for NZ dev)."
  type        = string
  default     = "ap-southeast-6"
}

variable "name" {
  description = "Name prefix for created resources."
  type        = string
  default     = "ipam-workload-a"
}

variable "pool_id" {
  description = "IPAM pool ID from the ipam stack output nz_dev_pool_id."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Example = "multi-account"
  }
}
