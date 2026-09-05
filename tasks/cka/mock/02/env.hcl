locals {
  questions_list="https://github.com/ViktorUJ/cks/blob/master/tasks/cka/mock/02/README.MD"
  solutions_scripts="https://github.com/ViktorUJ/cks/tree/master/tasks/cka/mock/02/worker/files/solutions"
  solutions_video="https://youtu.be/ia6Vw_BR-L0"
  region = "eu-north-1"
  vpc_default_cidr =  "10.2.0.0/16"
  az_ids = {
    "10.2.0.0/19"  = "eun1-az3"
    "10.2.32.0/19" = "eun1-az2"
  }
  aws    = "default"
  prefix = "cka-mock"
  tags   = {
    "env_name"        = "cka-mock2"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version           = "1.30.0"
  node_type            = "spot"
  runtime              = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type        = "t4g.medium" #  t3.medium  - x86     t4g.medium - arm
  instance_type_worker = "t4g.medium"
  key_name             = ""
  ubuntu_version       = "20.04"
  ssh_password_enable  = "true" # false |  true
  access_cidrs         = ["0.0.0.0/0"] #  "93.177.191.10/32"  | "0.0.0.0/0"
  ami_id               = "" #  ami-06410fb0e71718398 - x86   ami-0ff124a3d7381bfec - arm
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a    ami-0ebb6753c095cb52a - arm
  root_volume          = {
    type = "gp3"
    size = "12"
  }
}
