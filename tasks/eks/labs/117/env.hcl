locals {
  # Ветка, из которой worker тянет tests.bats и worker.sh при загрузке.
  # На время разработки - рабочая ветка; ПЕРЕД МЕРЖЕМ в master заменить на "master".
  git_branch        = "AG-155"
  raw_base_url      = "https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/${local.git_branch}"
  questions_list    = "https://github.com/ViktorUJ/cks/blob/${local.git_branch}/tasks/eks/labs/117/README_RU.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/${local.git_branch}/tasks/eks/labs/117/worker/files/solutions/1.MD"
  solutions_video   = "Not ready yet"
  debug_output      = "false"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.10.0.0/16"
  stack_name        = "eks117"
  user_id           = get_env("TF_VAR_USER_ID")
  env_id            = get_env("TF_VAR_ENV_ID")
  env_name          = "${local.stack_name}-${local.user_id}-${local.env_id}"
  # The network of this lab is intentionally mixed. Private subnets in
  # eu-central-1a and eu-central-1b use nat_gateway = "SUBNET", one NAT Gateway
  # per each of these two subnets. There is exactly one private subnet per zone
  # here, so "NAT per subnet" produces the same infrastructure as "NAT per AZ":
  # one NAT Gateway in eu-central-1a and one in eu-central-1b, the correct
  # layout from chapter 31. Mode "AZ" is deliberately not used: it groups
  # resources by AZ name, and the module resolves the AZ name through
  # data.aws_availability_zones, which is deferred because of the depends_on on
  # the module call inside vpc_v3. At plan time the zone name is unknown and
  # terraform fails with Invalid for_each argument. Mode "SUBNET" keys resources
  # by subnet keys, which are static, so the plan succeeds.
  # The third private subnet, in eu-central-1c, uses nat_gateway = "NONE": it
  # has a route table, but no 0.0.0.0/0 route in it, because vpc_v3 creates NAT
  # Gateways only for subnets with "AZ"/"SINGLE"/"SUBNET". The student adds a
  # route to the NAT Gateway of a neighbouring AZ by hand and gets the cross-AZ
  # NAT trap of task 2. All three private subnets carry the
  # karpenter.sh/discovery tag, so Karpenter can place nodes in the third AZ as
  # well.
  subnets = {
    public = {
      "pub1" = {
        name = "eks-AZ-1"
        cidr = "10.10.1.0/24"
        az   = "eu-central-1a"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/elb"                   = "1"
        }
      }
      "pub2" = {
        name = "eks-AZ-2"
        cidr = "10.10.2.0/24"
        az   = "eu-central-1b"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/elb"                   = "1"
        }
      }
    }
    private = {
      "eks1" = {
        name        = "private-subnet-1"
        cidr        = "10.10.15.0/24"
        az          = "eu-central-1a"
        nat_gateway = "SUBNET"
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
        nat_gateway = "SUBNET"
        type        = "eks"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/internal-elb"         = "1"
          "karpenter.sh/discovery"                  = "${local.env_name}"
        }
      }
      "eks3" = {
        name        = "private-subnet-3"
        cidr        = "10.10.17.0/24"
        az          = "eu-central-1c"
        nat_gateway = "NONE"
        type        = "eks"
        tags = {
          "kubernetes.io/cluster/${local.env_name}" = "owned"
          "kubernetes.io/role/internal-elb"         = "1"
          "karpenter.sh/discovery"                  = "${local.env_name}"
        }
      }
    }
  }

  aws    = "default"
  prefix = "eks-task117"
  tags = {
    "env_name"        = "eks-task117"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version           = "1.36.0"
  node_type            = "ondemand"   # ondemand | spot
  runtime              = "containerd" # docker , cri-o , containerd
  cni = {
    type               = "calico" # calico , cilium
    disable_kube_proxy = "false"
  }
  instance_type         = "t4g.medium" # m5.large | t4g.medium
  instance_type_worker  = "t3.medium"  # m5.large | t4g.medium
  spot_additional_types = ["c8g.xlarge", "t4g.medium", "m7g.large", "m7g.xlarge", "m8g.xlarge", "r7g.large", "t4g.large", "c7g.large", "c7g.xlarge", "c8g.large", "m6g.large", "m6g.xlarge", "t4g.xlarge"]
  all_spot_subnet       = "true"
  ubuntu_version        = "22.04"
  ami_id                = ""
  key_name              = ""
  ssh_password_enable   = "true"        # false | true
  access_cidrs          = ["0.0.0.0/0"] # "93.177.191.10/32" | "0.0.0.0/0"
  root_volume = {
    type = "gp3"
    size = "10"
  }
}
