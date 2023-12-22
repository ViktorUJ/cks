include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/work_pc/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}


dependency "vpc" {
  config_path = "../vpc"
}


dependency "eks" {
  config_path = "../eks"
}


inputs = {
  region                          = local.vars.locals.region
  aws                             = local.vars.locals.aws
  prefix                          = local.vars.locals.prefix
  tags_common                     = local.vars.locals.tags
  app_name                        = "k8s-worker"
  subnets_az                      = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id                          = dependency.vpc.outputs.vpc_id
  aws_eks_cluster_eks_cluster_arn = dependency.eks.outputs.aws_eks_cluster_eks_cluster_arn


  work_pc = {
    clusters_config    = {}
    instance_type      = local.vars.locals.instance_type
    node_type          = local.vars.locals.node_type
    ami_id             = local.vars.locals.ami_id
    key_name           = local.vars.locals.key_name
    cidrs              = ["0.0.0.0/0"]
    subnet_number      = "0"
    user_data_template = "template/worker_eks.sh"
    util = {
      kubectl_version = "v1.26.0"
    }
    exam_time_minutes = "360"
    test_url          = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/tests.bats"
    task_script_url   = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/worker.sh"
    ssh = {
      private_key = ""
      pub_key     = ""
    }
    root_volume      = local.vars.locals.root_volume
    non_root_volumes = {}
  }
}
