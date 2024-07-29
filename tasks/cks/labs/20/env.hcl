locals {
  questions_list = "https://github.com/ViktorUJ/cks/tree/master/tasks/cks/labs/20"
  solutions_scripts="https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/20/worker/files/solutions/22.MD"
  solutions_video="https://www.youtube.com/watch?v=IZsqAPpbBxM"
  region = "eu-north-1"
  aws    = "default"
  prefix = "cks-mock"
  tags = {
    "env_name"        = "cks-mock"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version           = "1.29.0"
  node_type            = "spot"
  runtime              = "containerd" # docker  , cri-o  , containerd ( need test it )
  instance_type        = "t4g.medium"
  instance_type_worker = "t4g.small"
  key_name             = ""
  ubuntu_version       = "20.04"
  ssh_password_enable  = "true" # false |  true
  access_cidrs         = ["0.0.0.0/0"]
  ami_id               = ""
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
  root_volume = {
    type = "gp3"
    size = "10"
  }
}
