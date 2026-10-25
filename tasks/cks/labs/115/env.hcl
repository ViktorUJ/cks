locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/AG-156/tasks/cks/labs/115/README_RU.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/AG-156/tasks/cks/labs/115/worker/files/solutions/1_RU.MD"
  solutions_video   = "Not ready yet"
  debug_output      = "false"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.115.0.0/16"
  aws               = "default"
  prefix            = "cks-task115"

  tags = {
    "env_name"        = "cks-task115"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }

  k8_version = "1.36.0"
  node_type  = "ondemand"
  runtime    = "containerd"
  # cni.type = "none" (not "cilium"): the shared module's own bootstrap only knows
  # how to auto-install "calico"/"cilium"; any other value hits its unsupported-type
  # branch and installs nothing. That is deliberate here - task 1 of this lab is to
  # observe a kube-proxy-free, CNI-less cluster before installing Cilium by hand
  # (task 2), so the module must not pre-install Cilium for us like it does for
  # labs/102 and labs/110.
  cni = {
    type                = "none"
    disable_kube_proxy  = "true"
    cilium_version      = "v0.19.7"
    cilium_helm_version = "1.20.1"
  }

  instance_type         = "t3.medium"
  instance_type_worker  = "t3.small"
  spot_additional_types = ["t3.medium"]
  all_spot_subnet       = "true"
  key_name              = ""
  ssh_password_enable   = "true"
  access_cidrs          = ["0.0.0.0/0"]
  ubuntu_version        = "22.04"
  ami_id                = ""

  root_volume = {
    type = "gp3"
    size = "10"
  }

  subnets = {
    public = {
      "pub1" = {
        name = "k8s-1"
        cidr = "10.115.1.0/24"
        az   = "eu-central-1a"
      }
      "pub2" = {
        name = "k8s-2"
        cidr = "10.115.2.0/24"
        az   = "eu-central-1b"
      }
    }
    private = {}
  }
}
