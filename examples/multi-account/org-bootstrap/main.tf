provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}

resource "aws_vpc_ipam_organization_admin_account" "ipam_admin" {
  delegated_admin_account_id = var.ipam_admin_account_id
}

# Must run in the org management account — member accounts cannot call this API.
resource "aws_ram_sharing_with_organization" "this" {}

resource "time_sleep" "wait_for_ram_org_sharing" {
  create_duration = var.ram_sharing_enable_wait_duration

  depends_on = [aws_ram_sharing_with_organization.this]
}
