include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_karpenter_vng/"

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

dependency "eks_karpenter" {
  config_path = "../eks_karpenter"
}

inputs = {
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  vpc_id   = dependency.vpc.outputs.vpc_id
  app_name = "eks_karpenter_vng_infra"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  nodepool = {}
  taints   = []
  # WhenEmpty вместо WhenEmptyOrUnderutilized сознательно, именно для этой лабы. Лаба
  # масштабирует нагрузку вверх и вниз, а Prometheus держит TSDB в emptyDir. С агрессивной
  # консолидацией (WhenEmptyOrUnderutilized плюс consolidateAfter 30s) Karpenter в момент
  # scale-down переселяет Prometheus, история метрики теряется, и HPA получает
  # <unknown>/100m вместо значения (проверено на живом стенде). Consolidation как тема
  # разбирается в лабе 123, здесь она только мешает.
  disruption = {
    consolidationPolicy = "WhenEmpty"
    consolidateAfter    = "1m"
  }
  requirements = [
    {
      key      = "kubernetes.io/arch"
      operator = "In"
      values   = ["amd64", "arm64"]
    },
    {
      key      = "kubernetes.io/os"
      operator = "In"
      values   = ["linux"]
    },
    {
      key      = "karpenter.sh/capacity-type"
      operator = "In"
      values   = ["spot", "on-demand"]
    },
    # Категория t исключена, а размеры начинаются с large: лабе нужен работающий стек
    # мониторинга плюс постоянная нагрузка на CPU. На t3.small (allocatable памяти около
    # 790 MiB) kubelet выселял Prometheus по memory pressure, а burstable-инстансы под
    # постоянной нагрузкой упираются в кредиты CPU и метрика становится нестабильной.
    {
      key      = "karpenter.k8s.aws/instance-category"
      operator = "In"
      values   = ["m", "r", "c"]
    },
    {
      key      = "karpenter.k8s.aws/instance-generation"
      operator = "Gt"
      values   = ["2"]
    },
    {
      key      = "karpenter.k8s.aws/instance-size"
      operator = "In"
      values   = ["large", "xlarge", "2xlarge"]
    }
  ]
  budgets = [
    { nodes = "33%" }
  ]
  vng = {
    labels = {
      work_type = "default"
    }
    name     = "default"
    iam_role = dependency.eks_karpenter.outputs.karpenter_module.node_iam_role_name
    tags     = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks-infra" })
  }
}
