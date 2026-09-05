locals {
  questions_list = "https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/07/README.MD"
  solutions_scripts="https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/07/worker/files/solutions/1.MD"
  solutions_video=""
  debug_output   = "false"
  region = "eu-north-1"
  vpc_default_cidr =  "10.2.0.0/16"

  az_ids = {
    "10.2.0.0/19"  = "eun1-az3"
    "10.2.32.0/19" = "eun1-az2"
  }
  aws    = "default"
  prefix = "cka-task05"
  tags = {
    "env_name"        = "cka-task07"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version           = "1.30.0"
  node_type            = "spot"
  runtime              = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type        = "t4g.medium"
  instance_type_worker = "t4g.small"
  key_name             = ""
  ssh_password_enable  = "true" # false |  true
  access_cidrs         = ["0.0.0.0/0"] #  "93.177.191.10/32"  | "0.0.0.0/0"
  ubuntu_version       = "20.04"
  ami_id               = ""
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
  root_volume = {
    type = "gp3"
    size = "10"
  }


}
