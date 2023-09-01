output "subnets_az" {
  value = local.subnets_az
}

output "subnets_az_cmdb" {
  value = local.subnets_az_cmdb
}

output "vpc_id" {
  value = aws_vpc.default.id
}
output "vpc_default_cidr" {
  value = var.vpc_default_cidr
}

output "env" {
  value = "${var.aws}-${var.prefix}-${var.app_name} "
}
