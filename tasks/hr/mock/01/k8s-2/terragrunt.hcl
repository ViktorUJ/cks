include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/k8s_self_managment/"
  #

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "vpc" {
  config_path = "../vpc"
}
dependency "ssh-keys" {
  config_path = "../ssh-keys"
}

inputs = {
  region       = local.vars.locals.region
  aws          = local.vars.locals.aws
  prefix       = "cluster2"
  tags_common  = local.vars.locals.tags
  app_name     = "k8s"
  subnets_az   = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id       = dependency.vpc.outputs.vpc_id
  cluster_name = "k8s2"
  node_type    = local.vars.locals.node_type

  k8s_master = {
    k8_version         = local.vars.locals.k8_version
    runtime            = local.vars.locals.runtime # docker  , cri-o  , containerd ( need test it ) , containerd_gvizor
    runtime_script     = "template/runtime.sh"
    instance_type      = local.vars.locals.instance_type
    key_name           = local.vars.locals.key_name
    ami_id             = local.vars.locals.ami_id
    subnet_number      = "0"
    ubuntu_version     = local.vars.locals.ubuntu_version
    user_data_template = "template/master.sh"
    pod_network_cidr   = "10.0.0.0/16"
    cidrs              = ["0.0.0.0/0"]
    eip                = "true"
    utils_enable       = "false"
    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/hr/mock/01/k8s-2/scripts/master.sh"
    calico_url         = "https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml"
    ssh = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
    root_volume = local.vars.locals.root_volume
  }
  k8s_worker = {
    # we can  configure each node independently

    "node_2" = {
      k8_version         = local.vars.locals.k8_version
      instance_type      = local.vars.locals.instance_type
      key_name           = local.vars.locals.key_name
      ami_id             = local.vars.locals.ami_id
      subnet_number      = "0"
      ubuntu_version     = local.vars.locals.ubuntu_version
      user_data_template = "template/worker.sh"
      runtime            = local.vars.locals.runtime
      runtime_script     = "template/runtime.sh"
      task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/hr/mock/01/k8s-2/scripts/worker.sh"
      node_labels        = "work_type=infra"
      ssh = {
        private_key = dependency.ssh-keys.outputs.private_key
        pub_key     = dependency.ssh-keys.outputs.pub_key
      }
      cidrs       = ["0.0.0.0/0"]
      root_volume = local.vars.locals.root_volume
    }
  }
}
