include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_extdns_irsa/"

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
  region            = local.vars.locals.region
  aws               = local.vars.locals.aws
  prefix            = local.vars.locals.prefix
  app_name          = "eks_extdns_irsa"
  name              = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  oidc_provider_arn = dependency.eks_control_plane.outputs.eks_mudule.oidc_provider_arn
  vpc_id            = dependency.vpc.outputs.vpc_id
  zone_domain       = local.vars.locals.zone_domain
  cert_common_name  = local.vars.locals.cert_common_name
  tags              = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks-extdns" })
}
