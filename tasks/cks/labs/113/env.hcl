locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/113/README_RU.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/113/worker/files/solutions/1_RU.MD"
  solutions_video   = "Not ready yet"
  debug_output      = "false"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.13.0.0/16"
  aws               = "default"
  prefix            = "cks-task113"
  tags = {
    env_name        = "cks-task113"
    env_type        = "dev"
    manage          = "terraform"
    cost_allocation = "dev"
    owner           = "viktoruj@gmail.com"
  }
  # Стартовая версия кластера для этой лабы - на минор младше training baseline (1.36),
  # чтобы задание "upgrade кластера" было реальным minor upgrade 1.35 -> 1.36, а не
  # no-op. После выполнения задания кластер окажется на той же baseline версии, что и
  # остальные core labs 101-112.
  k8_version = "1.35.4"
  node_type  = "ondemand"
  runtime    = "containerd"
  cni = {
    type               = "calico"
    disable_kube_proxy = "false"
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
    size = "20"
  }
  subnets = {
    public = {
      pub1 = { name = "k8s-1", cidr = "10.13.1.0/24", az = "eu-central-1a" }
      pub2 = { name = "k8s-2", cidr = "10.13.2.0/24", az = "eu-central-1b" }
    }
    private = {}
  }
}
