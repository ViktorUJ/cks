include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region                       = local.vars.locals.region
  aws                          = local.vars.locals.aws
  prefix                       = local.vars.locals.prefix
  eks_version                  = "1.24"
  vpc_id                       = dependency.vpc.outputs.vpc_id
  eks_node_common_desired_size = "1"
  eks_node_common_max_size     = "2"
  eks_node_common_min_size     = "1"
  eks_node_common_type         = ["t3.medium"]
  eks_capacity_type            = "SPOT"
  eks_allow_cidrs              = ["0.0.0.0/0"]
  cloudwatch_retention_in_days = "30"

}


