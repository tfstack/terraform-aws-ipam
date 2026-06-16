provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  workload_pool_cidr = "10.0.0.0/16"
  vpc_netmask_length = 20

  # First /20 from a fresh /16 pool matches IPAM's default next-CIDR allocation.
  # Subnet CIDRs must be plan-known because the VPC module uses length() for count.
  planned_vpc_cidr = cidrsubnet(local.workload_pool_cidr, local.vpc_netmask_length - 16, 0)

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  subnet_cidrs = cidrsubnets(local.planned_vpc_cidr, 4, 4, 4, 4, 4, 4)

  public_subnet_cidrs  = slice(local.subnet_cidrs, 0, 3)
  private_subnet_cidrs = slice(local.subnet_cidrs, 3, 6)
}

module "ipam" {
  source = "../.."

  pools = {
    workload = {
      cidr                              = [local.workload_pool_cidr]
      locale                            = var.region
      allocation_default_netmask_length = local.vpc_netmask_length
      description                       = "Workload pool for basic example"
    }
  }

  tags = var.tags
}

resource "aws_vpc_ipam_preview_next_cidr" "vpc" {
  ipam_pool_id   = module.ipam.pool_ids["workload"]
  netmask_length = local.vpc_netmask_length

  # Wait for pool CIDR provisioning; pool_id alone is available before the CIDR exists.
  depends_on = [module.ipam]
}

module "vpc" {
  source  = "cloudbuildlab/vpc/aws"
  version = "~> 1.0"

  vpc_name           = var.name
  vpc_cidr           = local.planned_vpc_cidr
  availability_zones = local.azs

  public_subnet_cidrs  = local.public_subnet_cidrs
  private_subnet_cidrs = local.private_subnet_cidrs

  tags = var.tags

  depends_on = [
    module.ipam,
    aws_vpc_ipam_preview_next_cidr.vpc,
  ]
}
