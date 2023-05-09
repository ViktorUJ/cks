include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  #source = "git::git@github.com:ViktorUJ/cks.git//terraform/modules/k8s_self_managment/?ref=task_01"
  source = "../../..//modules/work_pc/"

  extra_arguments "retry_lock" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=20m"]
  }

}

dependency "vpc" {
  config_path = "../vpc"
}

dependency "cluster1" {
  config_path = "clusters/k8s-1"
}

dependency "cluster2" {
  config_path = "clusters/k8s-2"
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


  work_pc= {
    clusters_config={
      cluster1=dependency.cluster1.outputs.k8s_config
      cluster2=dependency.cluster2.outputs.k8s_config
    }
    instance_type      = "t3.small"
    ami_id             = "ami-06410fb0e71718398"
    #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
    key_name           = "localize"
    cidrs              = ["0.0.0.0/0"]
    subnet_number      = "0"
    user_data_template = "template/worker.sh"
    util={
      kubectl_version="v1.26.0"
    }
    root_volume        = {
      type = "gp3"
      size = "12"
    }
  }


#    k8s_master = {
#    k8_version         = "1.26.0"
#    runtime            = "containerd" # docker  , cri-o  , containerd ( need test it )
#    runtime_script     = "template/runtime.sh"
#    instance_type      = "t3.medium"
#    key_name           = "localize"
#    ami_id             = "ami-06410fb0e71718398"
#    #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
#    subnet_number      = "0"
#    user_data_template = "template/master.sh"
#    pod_network_cidr   = "10.0.0.0/16"
#    cidrs              = ["0.0.0.0/0"]
#    utils_enable       = "false"
#    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/08/scripts/master.sh"
#    calico_url         = "https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml"
#    root_volume        = {
#      type = "gp3"
#      size = "12"
#    }
#  }
#  k8s_worker = {}
#


}

