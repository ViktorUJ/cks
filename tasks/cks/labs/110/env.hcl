locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/110/README_RU.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/110/worker/files/solutions/1_RU.MD"
  solutions_video   = "Not ready yet"
  debug_output      = "false"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.110.0.0/16"
  aws               = "default"
  prefix            = "cks-task110"
  tags = {
    "env_name"        = "cks-task110"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version = "1.36.0"
  node_type  = "ondemand"
  runtime    = "containerd"
  cni = {
    type               = "cilium"
    disable_kube_proxy = "false"
    cilium_version      = "v0.19.7"
    cilium_helm_version = "1.20.1"
  }
  instance_type         = "t3.medium"
  instance_type_worker  = "t3.medium"
  spot_additional_types = ["t3.medium"]
  all_spot_subnet       = "true"
  key_name              = ""
  ssh_password_enable   = "true"
  access_cidrs          = ["0.0.0.0/0"]
  ubuntu_version        = "22.04"
  ami_id                = ""

  root_volume = {
    type = "gp3"
    size = "16"
  }

  subnets = {
    public = {
      "pub1" = {
        name = "k8s-1"
        cidr = "10.110.1.0/24"
        az   = "eu-central-1a"
      }
      "pub2" = {
        name = "k8s-2"
        cidr = "10.110.2.0/24"
        az   = "eu-central-1b"
      }
    }
    private = {}
  }
}
