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
  region        = local.vars.locals.region
  aws           = local.vars.locals.aws
  prefix        = local.vars.locals.prefix
  tags_common   = local.vars.locals.tags
  app_name      = "k8s"
  subnets_az    = dependency.vpc.outputs.subnets_az_cmdb
  vpc_id        = dependency.vpc.outputs.vpc_id
  s3_k8s_config = "viktoruj-terraform-state-backet"

  k8s_master = {
    k8_version         = "1.24.10"
    runtime            = "cri-o" # docker  , cri-o  , containerd ( need test it ) , containerd_gvizor
    runtime_script     = "template/runtime.sh"
    instance_type      = "t3.medium"
    key_name           = "localize"
    ami_id             = "ami-03c68810c99d14e95"
    #  ubuntu  :  20.04 LTS  ami-03c68810c99d14e95   22.04 LTS  ami-00c70b245f5354c0a
    subnet_number      = "0"
    user_data_template = "template/master.sh"
    pod_network_cidr   = "10.0.0.0/16"
    cidrs              = ["0.0.0.0/0"]
    utils_enable       = "false"
    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/17-25_02_2023/tasks/cks/17/scripts/master.sh"
    calico_url         = "https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml"
    root_volume        = {
      type = "gp3"
      size = "15"
    }
  }
  k8s_worker = {
    # we can  configure each node independently
#  "node_1" = {
#    k8_version         = "1.25.0"
#    instance_type      = "t3.medium"
#    key_name           = "localize"
#    ami_id             = "ami-00c70b245f5354c0a"
#    subnet_number      = "0"
#    user_data_template = "template/worker.sh"
#    runtime            = "cri-o"
#    runtime_script     = "template/runtime.sh"
#    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/TASK_10/tasks/cks/10/scripts/worker.sh"
#    node_labels        = "work_type=falco,aws_scheduler=true"
#    cidrs              = ["0.0.0.0/0"]
#    root_volume        = {
#      type = "gp3"
#      size = "20"
#    }
#  }

#  "node_2" = {
#    k8_version         = "1.26.0"
#    instance_type      = "t3.large"
#    key_name           = "localize"
#    ami_id             = "ami-00c70b245f5354c0a"
#    subnet_number      = "0"
#    user_data_template = "template/worker.sh"
#    runtime            = "containerd_gvizor"
#    runtime_script     = "template/runtime.sh"
#    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/TASK_10/tasks/cks/10/scripts/worker.sh"
#    node_labels        = "work_type=infra_core,aws_scheduler=true,runtime=gvizor"
#
#    cidrs       = ["0.0.0.0/0"]
#    root_volume = {
#      type = "gp3"
#      size = "20"
#    }
#  }


  }
}

