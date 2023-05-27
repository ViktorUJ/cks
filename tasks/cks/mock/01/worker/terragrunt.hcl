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


inputs = {
  region        = local.vars.locals.region
  aws           = local.vars.locals.aws
  prefix        = local.vars.locals.prefix
  tags_common   = local.vars.locals.tags
  app_name      = "k8s-worker"
  subnets_az    = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id        = dependency.vpc.outputs.vpc_id
  s3_k8s_config = "viktoruj-terraform-state-backet"


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
    }
    instance_type      = "t3.medium"
    node_type          = "ondemand"
    ami_id             = "ami-06410fb0e71718398"
    #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
    key_name           = "cks"
    cidrs              = ["0.0.0.0/0"]
    subnet_number      = "0"
    user_data_template = "template/worker.sh"
    util               = {
      kubectl_version = "v1.26.0"
    }
    exam_time_minutes = "120"
    test_url          = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/tests.bats"
    task_script_url   = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/mock/01/worker/files/worker.sh"
    ssh               = {
      private_key = dependency.ssh-keys.outputs.private_key
      pub_key     = dependency.ssh-keys.outputs.pub_key
    }
    root_volume = {
      type = "gp3"
      size = "12"
    }
  }


}

