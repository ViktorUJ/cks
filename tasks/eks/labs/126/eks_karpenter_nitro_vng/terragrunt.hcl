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
  app_name = "eks_karpenter_vng_nitro"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  nodepool = {}
  # Без taint: под security groups for pods садится без toleration.
  taints = []
  disruption = {
    consolidationPolicy = "WhenEmptyOrUnderutilized"
    consolidateAfter    = "60s"
  }
  # Security groups for pods работают только на Nitro-инстансах (глава 46).
  # instance-category "c","m","r" уже исключает семейство "t" (это отдельная
  # категория), instance-generation > 4 - дополнительная гарантия, что взят
  # инстанс 5-го поколения и новее (все такие инстансы на AWS - Nitro).
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
      values   = ["on-demand"]
    },
    {
      key      = "karpenter.k8s.aws/instance-category"
      operator = "In"
      values   = ["c", "m", "r"]
    },
    {
      key      = "karpenter.k8s.aws/instance-generation"
      operator = "Gt"
      values   = ["4"]
    },
    {
      key      = "karpenter.k8s.aws/instance-size"
      operator = "In"
      values   = ["medium", "large", "xlarge"]
    }
  ]
  budgets = [
    { nodes = "33%" }
  ]
  vng = {
    labels = {
      work_type = "nitro"
    }
    name     = "nitro"
    iam_role = dependency.eks_karpenter.outputs.karpenter_module.node_iam_role_name
    tags     = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks-nitro" })
  }
}
