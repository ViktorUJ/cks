include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/worker_lfcs/"

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

inputs = {
  region      = local.vars.locals.region
  aws         = local.vars.locals.aws
  prefix      = local.vars.locals.prefix
  tags_common = local.vars.locals.tags
  app_name    = "worker-02"
  subnets_az  = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id      = dependency.vpc.outputs.vpc_id

  work_pc = {
    instance_type      = local.vars.locals.instance_type_worker2
    node_type          = local.vars.locals.node_type
    ami_id             = local.vars.locals.ami_id
    key_name           = local.vars.locals.key_name
    cidrs              = ["0.0.0.0/0"]
    subnet_number      = "0"
    ubuntu_version     = local.vars.locals.ubuntu_version
    user_data_template = "template/clean.sh"
    util = {
    }
    exam_time_minutes = "120"
    test_url          = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/lfcs/mock/01/worker/files/tests.bats"
    task_script_url   = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/lfcs/mock/01/worker/files/worker.sh"
    ssh = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
    root_volume      = local.vars.locals.root_volume
    non_root_volumes = {}
  }
}
