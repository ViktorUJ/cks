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

#
#subnets public

output "normalized_public_subnets_all" {
  value = module.vpc.normalized_public_subnets_all
}

output "subnets_public_raw" {
  value = module.vpc.subnets_public_raw
}
output "public_subnets_by_type" {
  value = module.vpc.public_subnets_by_type
}

output "public_subnets_by_az" {
  value = module.vpc.public_subnets_by_az
}

output "public_subnets_by_az_id" {
  value = module.vpc.public_subnets_by_az_id
}
#subnets private
output "normalized_private_subnets_all" {
  value = module.vpc.normalized_private_subnets_all
}

output "subnets_private_raw" {
  value =module.vpc.subnets_private_raw
}

output "private_subnets_by_type" {
  value = module.vpc.private_subnets_by_type
}

output "private_subnets_by_az" {
  value = module.vpc.private_subnets_by_az
}

output "private_subnets_by_az_id" {
  value = module.vpc.private_subnets_by_az_id
}

# NACL
output "nacl_default_rules_raw" {
  value = module.vpc.nacl_default_rules_raw
}
output "public_nacl_raw" {
  value = module.vpc.public_nacl_raw

}
output "public_nacl_rules_raw" {
  value = module.vpc.public_nacl_rules_raw
}


output "private_nacl_raw" {
  value = module.vpc.private_nacl_raw
}
output "private_nacl_rules_raw" {
  value = module.vpc.private_nacl_rules_raw
}

# NAT Gateway

output "nat_gateway_single_raw" {
  value = module.vpc.nat_gateway_single_raw
}

output "nat_gateway_subnet_raw" {
  value = module.vpc.nat_gateway_subnet_raw
}

output "nat_gateway_az_raw" {
  value = module.vpc.nat_gateway_az_raw
}

# Route Table
output "route_table_private_raw" {
  value = module.vpc.route_table_private_raw
}

output "route_table_public_raw" {
  value = module.vpc.route_table_public_raw
}
