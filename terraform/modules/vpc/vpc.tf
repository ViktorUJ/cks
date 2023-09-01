resource "aws_vpc" "default" {
  cidr_block           = var.vpc_default_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.tags_all
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
  tags   = local.tags_all
}
