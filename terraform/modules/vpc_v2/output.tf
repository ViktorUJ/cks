


output "subnets" {
  value = local.subnets
}
/*

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
  value = "${local.prefix}-${var.app_name} "
}
output "USER_ID" {
  value = local.USER_ID
}
output "ENV_ID" {
  value = local.ENV_ID
}
output "local_prefix" {
  value = local.prefix
}


 */
