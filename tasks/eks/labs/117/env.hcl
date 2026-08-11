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
  # Сеть этой лабы намеренно смешанная: приватные подсети в eu-central-1a и
  # eu-central-1b получают nat_gateway = "AZ" (по одному NAT Gateway на каждую
  # из этих двух AZ - правильная схема). Третья приватная подсеть, в
  # eu-central-1c, получает nat_gateway = "NONE": у неё есть таблица маршрутов,
  # но в ней нет маршрута 0.0.0.0/0 - модуль vpc_v3 создаёт NAT Gateway только
  # для подсетей с "AZ"/"SINGLE"/"SUBNET". Студент сам добавит в эту таблицу
  # маршрут на NAT Gateway соседней AZ - и получит ту самую ловушку cross-AZ
  # NAT из задания 2. Все три приватные подсети помечены
  # karpenter.sh/discovery, поэтому Karpenter умеет ставить ноды и в третью AZ.
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
        nat_gateway = "AZ"
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
        nat_gateway = "AZ"
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
