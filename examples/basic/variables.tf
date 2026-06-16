variable "region" {
  description = "AWS region for the example."
  type        = string
  default     = "ap-southeast-2"
}

variable "name" {
  description = "Name prefix for created resources."
  type        = string
  default     = "ipam-basic"
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    Example = "basic"
  }
}
