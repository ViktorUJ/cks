locals {
  questions_list = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/mock/04/README.MD"
  solutions_scripts="https://github.com/ViktorUJ/cks/tree/master/tasks/cks/mock/04/worker/files/solutions"
  solutions_video="https://youtu.be/9W9KvSGq3nc"
  debug_output   = "false"
  region         = "eu-central-1"
  vpc_default_cidr  = "10.10.0.0/16"

  subnets = {
    public = {
      "pub1" = {
        name = "AZ-1"
        cidr = "10.10.1.0/24"
        az   = "eu-central-1a"
      }
      "pub2" = {
        name = "AZ-2"
        cidr = "10.10.2.0/24"
        az   = "eu-central-1b"
      }

      "pub3" = {
        name = "AZ-3"
        cidr = "10.10.3.0/24"
        az   = "eu-central-1c"
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
  k8_version           = "1.34.1"
  node_type            = "spot"  # ondemand | spot
  runtime              = "containerd" # docker  , cri-o  , containerd ( need test it )
  cni = {
      type = "calico" #calico , cilium
      disable_kube_proxy="false"
    }
  instance_type        = "t4g.medium" # m5.large | t4g.medium
  instance_type_worker = "t4g.medium" # m5.large | t4g.medium
  spot_additional_types= [ "c8g.xlarge" , "t4g.medium" , "m6gd.2xlarge" , "m7g.large" , "m7g.xlarge" , "m7gd.large" , "m7gd.xlarge" , "m8g.xlarge" , "r6g.2xlarge" , "r6gd.2xlarge" , "r6gd.xlarge" , "r7g.large" , "r7gd.xlarge" , "t4g.large" , "c6gd.xlarge" , "c7g.large" , "c7g.xlarge" , "c7gd.2xlarge" , "c8g.large" , "m6g.large" , "m6g.xlarge" , "m6gd.large"  , "m6gd.xlarge" , "m7g.2xlarge"  , "m7gd.2xlarge" , "m8g.2xlarge" , "m8g.large"  , "r6g.xlarge" , "r6gd.large"  , "r7g.xlarge" , "r7gd.2xlarge" , "r7gd.large"  , "r8g.2xlarge" , "r8g.large" , "r8g.xlarge" , "t4g.2xlarge" , "t4g.xlarge" ]
  all_spot_subnet      = "true"
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
