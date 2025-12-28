include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_karpenter_vng/"

  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
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
  nodepool={}
  taints = [
  #   {
  #     key    = "dedicated"
  #     value  = "karpenter"
  #     effect = "NoSchedule"
  #   }
   ]
  disruption={
    consolidationPolicy="WhenEmptyOrUnderutilized"
    consolidateAfter   ="30s"
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
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["t", "m", "r","c"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["small","medium","large", "xlarge", "2xlarge", "4xlarge"]
            }

    ]
  budgets=[
    { nodes = "33%" }
  ]
  vng = {
    labels = {
        work_type = "infra"
    }
    name="infra"
    iam_role=dependency.eks_karpenter.outputs.karpenter_module.node_iam_role_name
    tags = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks-infra" })

  }

}
