locals {
  region = "eu-north-1"
  aws    = "default"
  prefix = "cka-mock"
  tags   = {
    "env_name"        = "cka-mock"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version    = "1.26.0"
  node_type     = "spot"
  runtime       = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type = "t3.medium"
  key_name      = "cks"
  s3_k8s_config = "viktoruj-terraform-state-backet"
  ami_id        = "ami-06410fb0e71718398"
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
  root_volume   = {
    type = "gp3"
    size = "12"
  }
}