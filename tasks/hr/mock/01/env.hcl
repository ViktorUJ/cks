locals {
  questions_list="https://github.com/ViktorUJ/cks/blob/0.7.1/tasks/hr/mock/01/README.md"
  region = "eu-north-1"
  aws    = "default"
  prefix = "hr-mock"
  tags = {
    "env_name"        = "hr-mock"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version           = "1.28.0"
  node_type            = "spot"
  runtime              = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type        = "t4g.medium" #  t3.medium  - x86     t4g.medium - arm
  instance_type_worker = "t4g.medium"
  key_name             = ""
  ubuntu_version       = "20.04"
  ami_id               = ""
  root_volume = {
    type = "gp3"
    size = "20"
  }
}
