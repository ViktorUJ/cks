locals {
  region = "eu-north-1"
  aws    = "default"
  prefix = "eks-01"
  tags   = {
    "env_name"        = "eks-01"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version    = "1.26.0"
  node_type     = "spot"
  instance_type = "t3.medium"
  key_name      = "cks"
  ami_id        = "ami-06410fb0e71718398"
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
  root_volume   = {
    type = "gp3"
    size = "12"
  }
}
