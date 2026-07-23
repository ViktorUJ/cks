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

dependency "node02" {
  config_path = "../node-2"
}

inputs = {
  questions_list    = local.vars.locals.questions_list
  solutions_scripts = local.vars.locals.solutions_scripts
  solutions_video   = local.vars.locals.solutions_video
  region            = local.vars.locals.region
  aws               = local.vars.locals.aws
  prefix            = local.vars.locals.prefix
  tags_common       = local.vars.locals.tags
  app_name          = "cp"
  subnets_az        = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id            = dependency.vpc.outputs.vpc_id
  vpc_cidr          = dependency.vpc.outputs.vpc_default_cidr
  host_list         = dependency.node02.outputs.hosts_list
  debug_output      = true

  work_pc = {
    instance_type      = local.vars.locals.instance_type_cp
    node_type          = local.vars.locals.node_type
    ami_id             = local.vars.locals.ami_id
    hostname           = "cp"
    key_name           = local.vars.locals.key_name
    cidrs              = ["0.0.0.0/0"]
    subnet_number      = "0"
    ubuntu_version     = local.vars.locals.ubuntu_version
    user_data_template = "template/worker_lfcs.sh"
    util               = {}
    exam_time_minutes  = "120"
    test_url           = "https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-154/tasks/cka/labs/116/node-1/files/tests.bats"
    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-154/tasks/cka/labs/116/node-1/files/worker.sh"
    ssh = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
    root_volume      = local.vars.locals.root_volume
    non_root_volumes = {}
  }
}
