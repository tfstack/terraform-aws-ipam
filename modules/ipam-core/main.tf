resource "aws_vpc_ipam" "this" {
  count = var.create ? 1 : 0

  description = var.description

  dynamic "operating_regions" {
    for_each = var.operating_regions
    content {
      region_name = operating_regions.value
    }
  }

  tags = var.tags
}
