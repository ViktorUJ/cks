include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/k8s_self_managment/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region       = local.vars.locals.region
  aws          = local.vars.locals.aws
  prefix       = local.vars.locals.prefix
  tags_common  = local.vars.locals.tags
  app_name     = "k8s"
  subnets_az   = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id       = dependency.vpc.outputs.vpc_id
  cluster_name = "k8s1"
  node_type    = local.vars.locals.node_type
  k8s_master   = {
    k8_version         = local.vars.locals.k8_version
    runtime            = "containerd"
    runtime_script     = "template/runtime.sh"
    instance_type      = local.vars.locals.instance_type
    key_name           = local.vars.locals.key_name
    ami_id             = local.vars.locals.ami_id
    ubuntu_version     = local.vars.locals.ubuntu_version
    subnet_number      = "0"
    user_data_template = "template/master.sh"
    pod_network_cidr   = "10.0.0.0/16"
    cidrs              = ["0.0.0.0/0"]
    eip                = "true"
    utils_enable       = "false"
    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/labs/04/k8s-1/scripts/master.sh"
    calico_url         = "https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml"
    ssh                = {
      private_key = ""
      pub_key     = ""
    }
    root_volume = {
      type = "gp3"
      size = "10"
    }
  }
  k8s_worker = {}
}
