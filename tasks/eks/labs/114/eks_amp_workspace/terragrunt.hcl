include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_amp_workspace/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }
}

inputs = {
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  app_name = "eks_amp_workspace"
  alias    = "${local.vars.locals.prefix}-amp"
  tags     = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-amp" })
}
