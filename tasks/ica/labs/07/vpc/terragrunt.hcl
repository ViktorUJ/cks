include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/vpc_v2/"
}

inputs = {
  region           = local.vars.locals.region
  aws              = local.vars.locals.aws
  prefix           = local.vars.locals.prefix
  tags_common      = local.vars.locals.tags
  app_name         = "network"
  vpc_default_cidr = local.vars.locals.vpc_default_cidr
  subnets          = local.vars.locals.subnets
  enable_dns_hostnames="true"


}
