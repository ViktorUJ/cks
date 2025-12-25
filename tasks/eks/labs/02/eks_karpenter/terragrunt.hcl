include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_fargate/"

  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}
dependency "vpc" {
  config_path = "../vpc"
}

dependency "eks_control_plane" {
  config_path = "../eks_control_plane"
}

dependency "eks_addons" {
  config_path = "../eks_addons"
}

dependency "eks_fargate_karpenter" {
  config_path = "../eks_fargate_karpenter"
}


inputs = {
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  vpc_id   = dependency.vpc.outputs.vpc_id
  app_name = "eks_karpenter"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  karpenter = {
    version ="1.7.1"
    tags = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks" })
  }

}
