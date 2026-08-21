include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_mng_healthy/"

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

dependency "eks_addons" {
  config_path = "../eks_addons"
}

inputs = {
  region     = local.vars.locals.region
  aws        = local.vars.locals.aws
  prefix     = local.vars.locals.prefix
  app_name   = "eks_mng_healthy"
  name       = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  subnet_ids = dependency.vpc.outputs.private_subnets_by_type.eks.ids
  mng = {
    name           = "healthy"
    instance_types = [local.vars.locals.instance_type_worker]
    ami_type       = "AL2023_x86_64_STANDARD"
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 2
    desired_size   = 1
    labels = {
      work_type = "healthy-baseline"
    }
    tags = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks-mng-healthy" })
  }
}
