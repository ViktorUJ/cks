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
  k8_version     = "1.28.0"
  node_type      = "spot" # ondemand  spot
  runtime        = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type  = "t4g.medium"
  key_name       = "cks"
  ami_id         = ""
  ubuntu_version = "20.04"
  root_volume    = {
    type = "gp3"
    size = "10"
  }
}
