include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/work_pc_v2/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "ssh-keys" {
  config_path = "../ssh-keys"
}

dependency "vpc" {
  config_path = "../vpc"
}


dependency "cluster1" {
  config_path = "../k8s-1"
}

inputs = {
  questions_list=local.vars.locals.questions_list
  solutions_scripts=local.vars.locals.solutions_scripts
  solutions_video=local.vars.locals.solutions_video
  region      = local.vars.locals.region
  aws         = local.vars.locals.aws
  prefix      = local.vars.locals.prefix
  tags_common = local.vars.locals.tags
  app_name    = "k8s-worker"
  subnets  = dependency.vpc.outputs.subnets
  vpc_id      = dependency.vpc.outputs.vpc_id

  host_list = concat(dependency.cluster1.outputs.hosts)
  work_pc = {
    clusters_config = {
      cluster1 = dependency.cluster1.outputs.k8s_config
    }
    instance_type      = local.vars.locals.instance_type_worker
    node_type          = local.vars.locals.node_type
    ami_id             = local.vars.locals.ami_id
    key_name           = local.vars.locals.key_name
    cidrs              = local.vars.locals.access_cidrs
    subnet_number      = "0"
    ubuntu_version     = local.vars.locals.ubuntu_version
    user_data_template = "template/worker.sh"
    util = {
      kubectl_version = local.vars.locals.k8_version
    }
    exam_time_minutes = "360"
    test_url          = "https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/labs/26/worker/files/tests.bats"
    task_script_url   = "https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/cks/labs/26/worker/files/worker.sh"
    ssh = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
    root_volume      = local.vars.locals.root_volume
    non_root_volumes = {}
  }
}
