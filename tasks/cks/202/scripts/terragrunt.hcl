include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  #source = "git::git@github.com:ViktorUJ/cks.git//terraform/modules/k8s_self_managment/?ref=task_01"
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
  s3_k8s_config = "viktoruj-terraform-state-backet-test1"
  cluster_name  = "k8s1"
  k8s_master    = {
    k8_version         = "1.26.0"
    runtime            = "containerd" # docker  , cri-o  , containerd ( need test it ) , containerd_gvizor
    runtime_script     = "template/runtime.sh"
    instance_type      = "t3.medium"
    key_name           = "cks"
    ami_id             = "ami-06410fb0e71718398"
    #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
    subnet_number      = "0"
    user_data_template = "template/master.sh"
    pod_network_cidr   = "10.0.0.0/16"
    cidrs              = ["0.0.0.0/0"]
    eip                = "true"
    utils_enable       = "true"
    task_script_url    = "https://raw.githubusercontent.com/ViktorUJ/cks/master/tasks/cks/202/scripts/master.sh"
    calico_url         = "https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml"
    ssh = {
        private_key = ""
        pub_key     = ""
      }
    root_volume        = {
      type = "gp3"
      size = "12"
    }
  }
  k8s_worker = {


  }
}

