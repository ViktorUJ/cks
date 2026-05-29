include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_control_plane/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region = local.vars.locals.region
  aws    = local.vars.locals.aws
  prefix = local.vars.locals.prefix
  vpc_id = dependency.vpc.outputs.vpc_id
  app_name         = "eks"
  eks = {
    name        = local.vars.locals.env_name
    version     = "1.34"
    vpc_id      = dependency.vpc.outputs.vpc_id
    subnet_ids  = dependency.vpc.outputs.private_subnets_by_type.eks.ids
    control_plane_subnet_ids = dependency.vpc.outputs.public_subnets_by_type.public.ids
    tags        = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks" })
  }
}
