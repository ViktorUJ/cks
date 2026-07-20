locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/123/README_RU.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/master/tasks/cka/labs/123/worker/files/solutions/1.MD"
  solutions_video   = "Not ready yet"
  debug_output      = "false"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.10.0.0/16"
  aws               = "default"
  prefix            = "cka-task123"
  tags = {
    "env_name"        = "cka-task123"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version = "1.35.2"
  node_type  = "ondemand"
  runtime    = "containerd"
  # CNI намеренно НЕ ставится модулем: студент устанавливает его руками.
  cni = {
    type               = "none"
    disable_kube_proxy = "false"
  }
  instance_type        = "t3.medium"
  instance_type_worker = "t3.small"
  spot_additional_types= [ "t3.medium" ]
  all_spot_subnet      = "true"
  key_name             = ""
  ssh_password_enable  = "true"
  access_cidrs         = ["0.0.0.0/0"]
  ubuntu_version       = "22.04"
  ami_id               = ""

  root_volume = {
    type = "gp3"
    size = "12"
  }

  subnets = {
    public = {
      "pub1" = {
        name = "k8s-1"
        cidr = "10.10.1.0/24"
        az   = "eu-central-1a"
      }
      "pub2" = {
        name = "k8s-2"
        cidr = "10.10.2.0/24"
        az   = "eu-central-1b"
      }
    }
    private = {}
  }
}
