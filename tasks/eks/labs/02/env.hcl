locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/master/tasks/eks/labs/02/README.MD"
  solutions_scripts = " not need"
  solutions_video   = "  need to add https://youtu.be/9W9KvSGq3nc"
  debug_output      = "false"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.10.0.0/16"
  stack_name        = "eks2"
  user_id           = get_env("TF_VAR_USER_ID")
  env_id            = get_env("TF_VAR_ENV_ID")
  env_name          = "${local.stack_name}-${local.user_id}-${local.env_id}"
  subnets = {
    public = {
      "pub1" = {
        name        = "eks-AZ-1"
        cidr        = "10.10.1.0/24"
        az          = "eu-central-1a"
        nat_gateway = "DEFAULT"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/elb"                  = "1"
        }
      }
      "pub2" = {
        name = "eks-AZ-2"
        cidr = "10.10.2.0/24"
        az   = "eu-central-1b"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/elb"                  = "1"
        }
      }


    }
    private = {

      "eks1" = {
        name        = "private-subnet-1"
        cidr        = "10.10.15.0/24"
        az          = "eu-central-1a"
        nat_gateway = "SINGLE"
        type        = "eks"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/internal-elb"         = "1"
          "karpenter.sh/discovery"                  = "${local.env_name}"
        }
      }
      "eks2" = {
        name        = "private-subnet-2"
        cidr        = "10.10.16.0/24"
        az          = "eu-central-1b"
        nat_gateway = "SINGLE"
        type        = "eks"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/internal-elb"         = "1"
          "karpenter.sh/discovery"                  = "${local.env_name}"
        }
      }
      "rds1" = {
        name        = "rds-subnet-1"
        cidr        = "10.10.21.0/24"
        az          = "eu-central-1a"
        nat_gateway = "NONE"
        type        = "rds"
      }
      "rds2" = {
        name        = "rds-subnet-2"
        cidr        = "10.10.22.0/24"
        az          = "eu-central-1b"
        nat_gateway = "NONE"
        type        = "rds"
      }
    }
  }

  aws    = "default"
  prefix = "eks-task"
  tags = {
    "env_name"        = "eks-task"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version = "1.34.1"
  node_type  = "ondemand"   # ondemand | spot
  runtime    = "containerd" # docker  , cri-o  , containerd ( need test it )
  cni = {
    type               = "calico" #calico , cilium
    disable_kube_proxy = "false"
  }
  instance_type         = "t4g.medium" # m5.large | t4g.medium
  instance_type_worker  = "t3.medium"  # m5.large | t4g.medium
  spot_additional_types = ["c8g.xlarge", "t4g.medium", "m6gd.2xlarge", "m7g.large", "m7g.xlarge", "m7gd.large", "m7gd.xlarge", "m8g.xlarge", "r6g.2xlarge", "r6gd.2xlarge", "r6gd.xlarge", "r7g.large", "r7gd.xlarge", "t4g.large", "c6gd.xlarge", "c7g.large", "c7g.xlarge", "c7gd.2xlarge", "c8g.large", "m6g.large", "m6g.xlarge", "m6gd.large", "m6gd.xlarge", "m7g.2xlarge", "m7gd.2xlarge", "m8g.2xlarge", "m8g.large", "r6g.xlarge", "r6gd.large", "r7g.xlarge", "r7gd.2xlarge", "r7gd.large", "r8g.2xlarge", "r8g.large", "r8g.xlarge", "t4g.2xlarge", "t4g.xlarge"]
  all_spot_subnet       = "true"
  ubuntu_version        = "22.04"
  ami_id                = ""
  key_name              = ""
  ssh_password_enable   = "true"        # false |  true
  access_cidrs          = ["0.0.0.0/0"] #  "93.177.191.10/32"  | "0.0.0.0/0"
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
  root_volume = {
    type = "gp3"
    size = "10"
  }
}
