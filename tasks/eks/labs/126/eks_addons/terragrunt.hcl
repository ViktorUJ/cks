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
  addons = {
    "coredns" = {
      version = "v1.14.3-eksbuild.3"
    }
    "kube-proxy" = {
      version = "v1.36.0-eksbuild.14"
    }
    # Security groups for pods (глава 46). ENABLE_POD_ENI=true создаёт trunk interface
    # (aws-k8s-trunk-eni) на нодах Karpenter. POD_SECURITY_GROUP_ENFORCING_MODE=standard
    # снимает требование DISABLE_TCP_EARLY_DEMUX на VPC CNI 1.11.0+ (проверено по
    # docs.aws.amazon.com/eks/latest/userguide/security-groups-pods-deployment.html).
    # Ключи проверены по конфигурации Helm-чарта aws-vpc-cni (env.ENABLE_POD_ENI,
    # env.POD_SECURITY_GROUP_ENFORCING_MODE не входит в его values.yaml как отдельный
    # флаг - используется общий блок env.*, куда VPC CNI managed addon прокидывает
    # произвольные переменные). Перед реальным прогоном сверить точную схему командой
    # aws eks describe-addon-configuration --addon-name vpc-cni --addon-version <version>.
    "vpc-cni" = {
      version = "v1.21.1-eksbuild.1"
      configuration = {
        env = {
          ENABLE_POD_ENI                    = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
      }
    }
    "eks-pod-identity-agent" = {
      version = "v1.3.10-eksbuild.2"
    }
  }
}
