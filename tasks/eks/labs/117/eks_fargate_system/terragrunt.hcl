include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_fargate/"

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

inputs = {
  region   = local.vars.locals.region
  aws      = local.vars.locals.aws
  prefix   = local.vars.locals.prefix
  vpc_id   = dependency.vpc.outputs.vpc_id
  app_name = "eks_fargate"
  name     = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  fargate = {
    name = "kube-system"
    # Only the subnets that have a NAT Gateway: eu-central-1a and eu-central-1b.
    # private-subnet-3 (eu-central-1c) is intentionally created without a
    # 0.0.0.0/0 route, it is the starting point of task 2. Fargate picks a
    # subnet for every pod at random from the profile list, and a pod landing
    # in private-subnet-3 cannot pull its image from ECR: coredns stays in
    # ImagePullBackOff and the addon hangs in CREATING until it times out.
    # So the profile only gets the zones that have internet egress.
    subnet_ids = concat(
      dependency.vpc.outputs.private_subnets_by_az["eu-central-1a"],
      dependency.vpc.outputs.private_subnets_by_az["eu-central-1b"],
    )
    selectors = [{ namespace = "kube-system" }, { namespace = "karpenter" }]
    tags      = merge(local.vars.locals.tags, { "Name" = "${local.vars.locals.prefix}-eks" })
  }
}
