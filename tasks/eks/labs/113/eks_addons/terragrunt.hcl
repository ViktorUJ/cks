include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_addons/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
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
  # Версии подобраны под control plane 1.35 (проверено на docs.aws.amazon.com,
  # страницы managing-coredns / managing-kube-proxy / managing-vpc-cni), на минор
  # ниже версий лабы 101 (там - под 1.36). kube-proxy и coredns привязаны к
  # минору control plane, vpc-cni и eks-pod-identity-agent к минору k8s не
  # привязаны, поэтому версии совпадают с лабой 101. Перед реальным прогоном
  # лабы сверить актуальность командой:
  #   aws eks describe-addon-versions --kubernetes-version 1.35 \
  #     --addon-name <coredns|kube-proxy|vpc-cni|eks-pod-identity-agent>
  addons = {
    "coredns" = {
      version = "v1.14.3-eksbuild.3"
    }
    "kube-proxy" = {
      version = "v1.35.3-eksbuild.13"
    }
    "vpc-cni" = {
      version = "v1.22.4-eksbuild.3"
    }
    "eks-pod-identity-agent" = {
      version = "v1.3.10-eksbuild.2"
    }
  }
}
