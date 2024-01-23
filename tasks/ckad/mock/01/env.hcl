locals {
  questions_list="https://github.com/ViktorUJ/cks/blob/0.7.1/tasks/ckad/mock/01/README.md"
  solutions_scripts="https://github.com/ViktorUJ/cks/tree/0.7.1/tasks/ckad/mock/01/worker/files/solutions"
  solutions_video="https://youtu.be/yQK7Ca8d-yw"
  region = "eu-north-1"
  aws    = "default"
  prefix = "ckad-mock"
  tags = {
    "env_name"        = "ckad-mock"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version           = "1.28.0"
  node_type            = "spot"
  runtime              = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type        = "t4g.medium" #  t3.medium  - x86     t4g.medium - arm
  instance_type_worker = "t4g.small"
  key_name             = ""
  ssh_password_enable  = "true" # false |  true
  access_cidrs         = ["0.0.0.0/0"] #  "93.177.191.10/32"  | "0.0.0.0/0"
  ubuntu_version       = "20.04"
  ami_id               = ""
  root_volume = {
    type = "gp3"
    size = "12"
  }
}
