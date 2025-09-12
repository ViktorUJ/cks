include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/k8s_self_managment_v2/"
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
  prefix       = "cluster3"
  tags_common  = local.vars.locals.tags
  app_name     = "k8s"
  subnets      = dependency.vpc.outputs.subnets
  vpc_id       = dependency.vpc.outputs.vpc_id
  cluster_name = "k8s3"
  node_type    = local.vars.locals.node_type
  ssh_password_enable =local.vars.locals.ssh_password_enable
  spot_additional_types = local.vars.locals.spot_additional_types
  all_spot_subnet       = local.vars.locals.all_spot_subnet

  k8s_master = {
    k8_version         = local.vars.locals.k8_version
    runtime            = local.vars.locals.runtime # docker  , cri-o  , containerd ( need test it )
    runtime_script     = "template/runtime.sh"
    instance_type      = local.vars.locals.instance_type
    key_name           = local.vars.locals.key_name
    ami_id             = local.vars.locals.ami_id
    ubuntu_version     = local.vars.locals.ubuntu_version
    subnet_number      = "2"
    user_data_template = "template/master.sh"
    pod_network_cidr   = "10.0.0.0/16"
    cidrs              = local.vars.locals.access_cidrs
    eip                = "false"
    utils_enable       = "false"
    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/k8s-3/scripts/master.sh"
    cni                = local.vars.locals.cni
    root_volume        = local.vars.locals.root_volume
    ssh = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
  }
  k8s_worker = {
    "node_1" = {
      k8_version         = local.vars.locals.k8_version
      instance_type      = local.vars.locals.instance_type
      key_name           = local.vars.locals.key_name
      ami_id             = local.vars.locals.ami_id
      ubuntu_version     = local.vars.locals.ubuntu_version
      subnet_number      = "0"
      user_data_template = "template/worker.sh"
      runtime            = local.vars.locals.runtime
      runtime_script     = "template/runtime.sh"
      task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/03/k8s-3/scripts/worker.sh"
      node_labels        = "work_type=worker"
      cidrs              = local.vars.locals.access_cidrs
      root_volume        = local.vars.locals.root_volume
      ssh = {
        private_key = dependency.ssh-keys.outputs.private_key
        pub_key     = dependency.ssh-keys.outputs.pub_key
      }
    }

  }
}
