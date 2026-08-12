include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_efs_irsa/"

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
dependency "eks_fargate_system" {
  config_path = "../eks_fargate_system"
}

inputs = {
  region                    = local.vars.locals.region
  aws                       = local.vars.locals.aws
  prefix                    = local.vars.locals.prefix
  app_name                  = "eks_v2_efs_irsa"
  name                      = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  oidc_provider_arn         = dependency.eks_control_plane.outputs.eks_mudule.oidc_provider_arn
  vpc_id                    = dependency.vpc.outputs.vpc_id
  subnet_ids                = dependency.vpc.outputs.private_subnets_by_type.eks.ids
  security_group_source_id  = dependency.eks_control_plane.outputs.eks_mudule.node_security_group_id
  tags                      = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks" })
  addons = {
    name    = "aws-efs-csi-driver"
    # Версию проверить перед продом: значение подобрано как разумное для EKS 1.36,
    # сверить через `aws eks describe-addon-versions --addon-name aws-efs-csi-driver`.
    version = "v3.4.1-eksbuild.1"
    # По умолчанию контроллер требует containerSecurityContext.privileged: true
    # (нужно только для опции delete-access-point-root-dir, которая в этой лабе не
    # используется). namespace kube-system целиком закрыт Fargate-профилем
    # (eks_fargate_system), а Fargate не поддерживает privileged поды - без этого
    # override под efs-csi-controller навечно остаётся FailedScheduling и managed
    # addon висит в DEGRADED/CREATE_FAILED.
    configuration = {
      controller = {
        containerSecurityContext = {
          privileged = false
        }
      }
    }
  }
}
