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
    # (aws-k8s-trunk-eni) на нодах Karpenter.
    #
    # РЕЖИМ ЗДЕСЬ strict (значение по умолчанию), и это принципиально для лабы. В режиме
    # standard правила SG пода НЕ применяются к трафику между подом и kubelet на той же
    # ноде (прямая цитата из docs.aws.amazon.com/eks/latest/userguide/
    # security-groups-pods-deployment.html), поэтому readiness-проба проходит даже при SG
    # без единого inbound-правила - симптом заданий 4 и 5 воспроизвести невозможно
    # (проверено на живом стенде: под сразу становился 1/1 Ready).
    #
    # В strict пробы kubelet идут через branch ENI и подчиняются правилам SG пода, но для
    # этого нужен DISABLE_TCP_EARLY_DEMUX=true на init-контейнере aws-node - иначе kubelet
    # не может открыть TCP к поду на branch ENI ВООБЩЕ, и добавление правила ничего не
    # починит. Схема конфигурации аддона это поддерживает: init.env.DISABLE_TCP_EARLY_DEMUX
    # (проверено командой aws eks describe-addon-configuration --addon-name vpc-cni).
    # Вложенный блок init нельзя передать через configuration: у переменной addons тип
    # optional(any), terraform сводит типы всех элементов к общему и падает с
    # "cannot find a common base type for all elements" (поймано вживую, на destroy).
    # Поэтому здесь configuration_json - готовая JSON-строка, модуль отдаёт её в
    # configuration_values как есть.
    "vpc-cni" = {
      version = "v1.21.1-eksbuild.1"
      configuration_json = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "strict"
        }
        init = {
          env = {
            DISABLE_TCP_EARLY_DEMUX = "true"
          }
        }
      })
    }
    "eks-pod-identity-agent" = {
      version = "v1.3.10-eksbuild.2"
    }
  }
}
