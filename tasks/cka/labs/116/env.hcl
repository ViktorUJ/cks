locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/116/README_RU.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/116/node-1/files/solutions/1.MD"
  solutions_video   = "Not ready yet"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.20.0.0/16"
  az_ids = {
    "10.20.0.0/19"  = "euc1-az1"
    "10.20.32.0/19" = "euc1-az2"
  }
  aws        = "default"
  prefix     = "cka-task116"
  git_branch = "master"
  tags = {
    "env_name"        = "cka-task116"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  node_type            = "ondemand"
  instance_type_cp     = "t3.medium"
  instance_type_worker = "t3.small"
  key_name             = ""
  ubuntu_version       = "22.04"
  ami_id               = ""
  root_volume = {
    type = "gp3"
    size = "15"
  }
}
