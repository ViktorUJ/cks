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

inputs = {
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  vpc_id   = dependency.vpc.outputs.vpc_id
  app_name = "eks_fargate"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  fargate = {
    name       = "kube-system"
    subnet_ids = dependency.vpc.outputs.private_subnets_by_type.eks.ids
    selectors = [{ namespace = "kube-system" },{ namespace = "karpenter" }]
    tags = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks" })
  }

}
