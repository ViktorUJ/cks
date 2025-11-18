locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/30/README.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/30/worker/files/solutions/1.MD"
  solutions_video   = "Not ready yet"
  debug_output      = "false"
  region            = "eu-north-1"
  vpc_default_cidr  = "10.10.0.0/16"
  aws               = "default"
  prefix            = "cks-task30"
  tags = {
    "env_name"        = "cks-task30"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version = "1.34.0"
  node_type  = "spot"
  runtime    = "containerd" # docker, cri-o, containerd ( need test it )
  cni = {
    type               = "cilium" #calico , cilium
    disable_kube_proxy = "true"
  }
  instance_type        = "t4g.medium"
  instance_type_worker = "t4g.small"
  spot_additional_types= [ "t4g.medium" , "t4g.large" , "t4g.xlarge" ]
  all_spot_subnet      = "true"
  key_name             = ""
  ssh_password_enable  = "true"        # false |  true
  access_cidrs         = ["0.0.0.0/0"] #  "93.177.191.10/32"  | "0.0.0.0/0"
  ubuntu_version       = "22.04"
  ami_id               = ""

  root_volume = {
    type = "gp3"
    size = "10"
  }

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
}
