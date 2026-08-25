include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_network_break_demo/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }
}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "eks_control_plane" {
  config_path = "../eks_control_plane"
}

inputs = {
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  app_name = "network-break-demo"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  vpc_id   = dependency.vpc.outputs.vpc_id
  tags     = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-network-break" })
}
