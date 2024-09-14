


output "subnets" {
  value = local.subnets
}
output "vpc_id" {
  value = local.vpc_id
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

output "vpc_default_cidr" {
  value = var.vpc_default_cidr
}


/*

output "subnets_az_cmdb" {
  value = local.subnets_az_cmdb
}



output "env" {
  value = "${local.prefix}-${var.app_name} "
}



 */
