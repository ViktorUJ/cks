include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_ebs_irsa/"

  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "eks_fargate_system" {
  config_path = "../eks_fargate_system"
}
dependency "eks_control_plane" {
  config_path = "../eks_control_plane"
}


inputs = {
  region            = local.vars.locals.region
  aws               = local.vars.locals.aws
  prefix            = local.vars.locals.prefix
  app_name          = "eks_v2_ebs_irsa"
  name              = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  oidc_provider_arn = dependency.eks_control_plane.outputs.eks_mudule.oidc_provider_arn
  tags = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks" })
  addons = {
    name    = "aws-ebs-csi-driver"
    version = "v1.54.0-eksbuild.1"
  }
}

# aws-ebs-csi-driver = "v1.53.0-eksbuild.1"