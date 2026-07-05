variable "vpc_name" {
  description = "Name tag for the VPC and related resources."
  type        = string
}

variable "ipv4_ipam_pool_id" {
  description = "IPAM pool ID used to allocate the VPC CIDR (creates a formal pool allocation)."
  type        = string
}

variable "ipv4_netmask_length" {
  description = "Netmask length for the VPC CIDR allocated from the IPAM pool."
  type        = number
  default     = 20
}

variable "availability_zones" {
  description = "Availability zones for public and private subnets (same length for each tier)."
  type        = list(string)
}

variable "subnet_newbits" {
  description = "Additional prefix bits when splitting the VPC CIDR into /24 subnets (/20 VPC + 4 = /24)."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags applied to created resources."
  type        = map(string)
  default     = {}
}
