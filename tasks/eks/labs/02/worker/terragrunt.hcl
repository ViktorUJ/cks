include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/eks_v2_work_pc/"

  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "ssh-keys" {
  config_path = "../ssh-keys"
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
  questions_list        = local.vars.locals.questions_list
  solutions_scripts     = local.vars.locals.solutions_scripts
  solutions_video       = local.vars.locals.solutions_video
  debug_output          = local.vars.locals.debug_output
  region                = local.vars.locals.region
  aws                   = local.vars.locals.aws
  prefix                = local.vars.locals.prefix
  tags_common           = local.vars.locals.tags
  app_name              = "worker_eks"
  subnets               = dependency.vpc.outputs.subnets
  vpc_id                = dependency.vpc.outputs.vpc_id
  ssh_password_enable   = local.vars.locals.ssh_password_enable
  all_spot_subnet       = local.vars.locals.all_spot_subnet
  spot_additional_types = local.vars.locals.spot_additional_types
  name                  = dependency.eks_control_plane.outputs.eks_mudule.cluster_name
  karpenter_node_iam_role_name = dependency.eks_karpenter.outputs.karpenter_module.node_iam_role_name
  work_pc = {
    instance_type      = local.vars.locals.instance_type_worker
    node_type          = local.vars.locals.node_type
    ami_id             = local.vars.locals.ami_id
    ubuntu_version     = local.vars.locals.ubuntu_version
    key_name           = local.vars.locals.key_name
    eks_config_url     = dependency.eks_control_plane.outputs.kubectl_config
    cidrs              = local.vars.locals.access_cidrs
    subnet_number      = "0"
    user_data_template = "template/worker_eks.sh"
    util = {
      kubectl_version = local.vars.locals.k8_version
    }
    exam_time_minutes = "700"
    test_url          = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/04/worker/files/tests.bats"
    task_script_url   = "https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/worker.sh"
    ssh = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
    root_volume = local.vars.locals.root_volume
    non_root_volumes = {}
  }


}
