
resource "aws_subnet" "subnets_pub" {
  vpc_id                  = aws_vpc.default.id
  for_each                = var.az_ids
  map_public_ip_on_launch = true
  cidr_block              = each.key
  availability_zone_id    = each.value
  tags                    = local.tags_all
  lifecycle {
    ignore_changes = [
      tags,
      tags_all
    ]
  }
}
