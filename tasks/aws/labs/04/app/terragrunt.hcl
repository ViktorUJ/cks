include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/aws/app4"
  #

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region              = local.vars.locals.region
  aws                 = local.vars.locals.aws
  prefix              = "awsgame"
  tags_common         = local.vars.locals.tags
  app_name            = "04"
  subnets             = dependency.vpc.outputs.private_subnets_by_type.intra.id
  vpc_id              = dependency.vpc.outputs.vpc_id

}
