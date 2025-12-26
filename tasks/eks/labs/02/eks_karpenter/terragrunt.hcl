include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_karpenter/"

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

dependency "eks_fargate_system" {
  config_path = "../eks_fargate_system"
}


inputs = {
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  vpc_id   = dependency.vpc.outputs.vpc_id
  app_name = "eks_karpenter"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  karpenter = {
    irsa_oidc_provider_arn               = dependency.eks_control_plane.outputs.eks_mudule.oidc_provider_arn
    namespace                            = "karpenter"
    version                              = "1.8.1"
    controller_replicas                  = "1"
    controller_resources_requests_cpu    = "0.4"
    controller_resources_requests_memory = "0.5Gi"
    controller_resources_limits_cpu      = "0.4"
    controller_resources_limits_memory   = "0.5Gi"
    tags = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks" })
  }

}
