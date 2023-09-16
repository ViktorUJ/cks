locals {
  region = "eu-north-1"
  aws    = "default"
  prefix = "cks-mock"
  tags   = {
    "env_name"        = "cks-mock"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version    = "1.27.0"
  node_type     = "spot"
  runtime       = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type = "t4g.medium"
  key_name      = "cks"
  ami_id        = "ami-0ff124a3d7381bfec"
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
  root_volume   = {
    type = "gp3"
    size = "12"
  }
}
