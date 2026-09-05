include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_addons/"

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
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  app_name = "eks_addons"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  addons = {
    "coredns" = {
      version = "v1.12.4-eksbuild.1"
    }
    "kube-proxy" = {
      version = "v1.34.1-eksbuild.2"
    }
    "vpc-cni" = {
      version = "v1.21.1-eksbuild.1"
    }
    "eks-pod-identity-agent" = {
      version = "v1.3.10-eksbuild.2"
    }
  }
}
