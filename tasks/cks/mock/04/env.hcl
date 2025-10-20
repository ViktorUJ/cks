locals {
  questions_list = "https://github.com/ViktorUJ/cks/blob/AG-120/tasks/cks/mock/04/README.MD"
  solutions_scripts="https://github.com/ViktorUJ/cks/tree/AG-120/tasks/cks/mock/04/worker/files/solutions"
  solutions_video="need to update. old version https://youtu.be/I8CPwcGbrG8"
  debug_output   = "false"
  region         = "eu-north-1"
  vpc_default_cidr  = "10.10.0.0/16"

  subnets = {
    public = {
      "pub1" = {
        name = "AZ-1"
        cidr = "10.10.1.0/24"
        az   = "eu-north-1a"
      }
      "pub2" = {
        name = "AZ-2"
        cidr = "10.10.2.0/24"
        az   = "eu-north-1b"
      }

      "pub3" = {
        name = "AZ-3"
        cidr = "10.10.3.0/24"
        az   = "eu-north-1c"
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
 #spot_additional_types= [ "t4g.medium" , "t4g.large" , "t4g.xlarge" ]
spot_additional_types=  [ "c5a.2xlarge" , "c5a.large" , "c5a.xlarge" , "c5d.large" , "c5n.large" , "c5n.xlarge"  , "c7i-flex.xlarge" , "c7i.large" , "i3en.large" , "i7ie.2xlarge" , "m5.xlarge" , "m6i.xlarge" , "m6idn.xlarge" , "m7a.large" , "m7a.medium" , "m7i-flex.large" , "r5.2xlarge" , "r5.large" , "r5.xlarge" , "r5b.large" , "r5b.xlarge" , "r5d.2xlarge" , "r5d.large" , "r5dn.2xlarge" , "r5dn.large" , "r5dn.xlarge" , "r5n.2xlarge" , "r5n.large" , "r5n.xlarge" , "r6i.xlarge" , "r6idn.2xlarge" , "r6idn.large" , "r6idn.xlarge" , "r6in.2xlarge" , "r6in.large" , "r6in.xlarge" , "r7a.2xlarge" , "r7a.large" , "r7a.medium" , "r7i.large" , "t3.2xlarge" , "t3.large" , "t3.medium" , "t3.xlarge" , "x2iedn.2xlarge" , "x2iedn.xlarge" , "c5d.xlarge" , "c7i-flex.large" , "c7i.xlarge" ]
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
