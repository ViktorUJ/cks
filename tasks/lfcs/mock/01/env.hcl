locals {
  region           = "eu-north-1"
  vpc_default_cidr = "10.2.0.0/16"
  az_ids = {
    "10.2.0.0/19"  = "eun1-az3"
    "10.2.32.0/19" = "eun1-az2"
  }
  aws        = "default"
  prefix     = "lfcs"
  git_branch = "lfcs_preparation"
  tags = {
    "env_name"        = "lfcs-mock"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  node_type             = "spot"
  instance_type_worker1 = "t4g.medium" #  t3.medium  - x86     t4g.medium - arm
  instance_type_worker2 = "t4g.micro"
  key_name              = ""
  ubuntu_version        = "20.04"
  ami_id                = ""
  root_volume = {
    type = "gp3"
    size = "12"
  }
}
