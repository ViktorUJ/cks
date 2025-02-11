locals {
  questions_list = "https://github.com/ViktorUJ/cks/blob/AG-92/tasks/cks/mock/02/README.MD"
  solutions_scripts="https://github.com/ViktorUJ/cks/tree/AG-92/tasks/cks/mock/02/worker/files/solutions"
  solutions_video="need to update . old version https://youtu.be/I8CPwcGbrG8"
  debug_output   = "false"
  region         = "eu-north-1"
  vpc_default_cidr  = "10.10.0.0/16"

  subnets = {
    public = {
      "pub1" = {
        name = "k8s-1"
        cidr = "10.10.1.0/24"
        az   = "eu-north-1a"
      }
      "pub2" = {
        name = "k8s-2"
        cidr = "10.10.2.0/24"
        az   = "eu-north-1b"
      }


    }
    private = {}
  }

  aws            = "default"
  prefix         = "cks-mock"
  tags           = {
    "env_name"        = "cks-mock"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version           = "1.32.0"
  node_type            = "spot"  # ondemand | spot
  runtime              = "containerd" # docker  , cri-o  , containerd ( need test it )
  cni = {
      type = "calico" #calico , cilium
      disable_kube_proxy="false"
    }
  instance_type        = "m6g.medium" # m5.large | t4g.medium
  instance_type_worker = "m6g.medium" # m5.large | t4g.medium
  ubuntu_version       = "22.04"
  ami_id               = ""
  key_name             = ""
  ssh_password_enable  = "true" # false |  true
  access_cidrs         = ["0.0.0.0/0"] #  "93.177.191.10/32"  | "0.0.0.0/0"
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
  root_volume          = {
    type = "gp3"
    size = "10"
  }
}
