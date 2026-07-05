provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }
}

locals {
  vpc_netmask_length = 20
  azs                = slice(data.aws_availability_zones.available.names, 0, 3)
  demo_private_ip    = cidrhost(module.ipam_vpc.first_public_subnet_cidr, 5)
  demo_host_cidr     = "${local.demo_private_ip}/32"
}

module "ipam_vpc" {
  source = "../modules/ipam-vpc"

  vpc_name            = var.name
  ipv4_ipam_pool_id   = var.pool_id
  ipv4_netmask_length = local.vpc_netmask_length
  availability_zones  = local.azs
  tags                = var.tags
}

resource "aws_security_group" "demo" {
  name_prefix = "${var.name}-demo-"
  vpc_id      = module.ipam_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_ec2_subnet_cidr_reservation" "demo" {
  subnet_id        = module.ipam_vpc.public_subnet_ids[0]
  cidr_block       = local.demo_host_cidr
  reservation_type = "explicit"
  description      = "Demo EC2 static host (.5)"
}

resource "aws_instance" "demo" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.nano"
  subnet_id              = module.ipam_vpc.public_subnet_ids[0]
  private_ip             = local.demo_private_ip
  vpc_security_group_ids = [aws_security_group.demo.id]

  tags = merge(var.tags, { Name = "${var.name}-demo" })

  depends_on = [aws_ec2_subnet_cidr_reservation.demo]
}
