include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/work_pc/"
  # source = "../../..//modules/work_pc_ondemand/"

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

dependency "cluster2" {
  config_path = "../k8s-2"
}

dependency "cluster3" {
  config_path = "../k8s-3"
}

dependency "cluster4" {
  config_path = "../k8s-4"
}

dependency "cluster5" {
  config_path = "../k8s-5"
}

dependency "cluster6" {
  config_path = "../k8s-6"
}

dependency "cluster7" {
  config_path = "../k8s-7"
}

dependency "cluster8" {
  config_path = "../k8s-8"
}

dependency "cluster9" {
  config_path = "../k8s-9"
}
dependency "cluster10" {
  config_path = "../k8s-10"
}
inputs = {
  region      = local.vars.locals.region
  aws         = local.vars.locals.aws
  prefix      = local.vars.locals.prefix
  tags_common = local.vars.locals.tags
  app_name    = "k8s-worker"
  subnets_az  = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id      = dependency.vpc.outputs.vpc_id


  work_pc = {
    clusters_config = {
      cluster1 = dependency.cluster1.outputs.k8s_config
      cluster2 = dependency.cluster2.outputs.k8s_config
      cluster3 = dependency.cluster3.outputs.k8s_config
      cluster4 = dependency.cluster4.outputs.k8s_config
      cluster5 = dependency.cluster5.outputs.k8s_config
      cluster6 = dependency.cluster6.outputs.k8s_config
      cluster7 = dependency.cluster7.outputs.k8s_config
      cluster8 = dependency.cluster8.outputs.k8s_config
      cluster9 = dependency.cluster9.outputs.k8s_config
      cluster10 = dependency.cluster10.outputs.k8s_config
    }
    instance_type      = local.vars.locals.instance_type_worker
    node_type          = local.vars.locals.node_type
    ami_id             = local.vars.locals.ami_id
    ubuntu_version     = local.vars.locals.ubuntu_version
    key_name           = local.vars.locals.key_name
    cidrs              = ["0.0.0.0/0"]
    subnet_number      = "0"
    user_data_template = "template/worker.sh"
    util               = {
      kubectl_version = local.vars.locals.k8_version
    }
    exam_time_minutes = "120"
    test_url          = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/tests.bats"
    task_script_url   = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/worker.sh"
    ssh               = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
    root_volume = local.vars.locals.root_volume
  }


}
