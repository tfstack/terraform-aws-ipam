variable "region" {
  description = "AWS region for the workload VPC (ap-southeast-2 for AU sandbox)."
  type        = string
  default     = "ap-southeast-2"
}

variable "name" {
  description = "Name prefix for created resources."
  type        = string
  default     = "ipam-workload-b"
}

variable "pool_id" {
  description = "IPAM pool ID from the ipam stack output au_sandbox_pool_id."
  type        = string
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Example = "multi-account"
  }
}
