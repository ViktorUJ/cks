resource "aws_route_table" "pub" {
  vpc_id = aws_vpc.default.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.default.id
  }
  tags = local.tags_all
}



resource "aws_route_table_association" "pub" {
  depends_on = [
    aws_subnet.subnets_pub
  ]
  for_each       = var.az_ids
  route_table_id = aws_route_table.pub.id
  subnet_id      = aws_subnet.subnets_pub["${each.key}"].id
}
