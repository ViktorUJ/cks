locals {
  questions_list    = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/28/README.MD"
  solutions_scripts = "https://github.com/ViktorUJ/cks/blob/master/tasks/cks/labs/28/worker/files/solutions/1.MD"
  solutions_video   = "https://youtu.be/-uEHbkI3wcs"
  debug_output      = "false"
  region            = "eu-north-1"
  vpc_default_cidr  = "10.10.0.0/16"
  aws               = "default"
  prefix            = "cks-task28"
  tags = {
    "env_name"        = "cka-task28"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }
  k8_version = "1.33.0"
  node_type  = "spot"
  runtime    = "containerd"
  cni = {
    type               = "calico"
    disable_kube_proxy = "false"
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
  #  ubuntu  :  20.04 LTS  ami-06410fb0e71718398     22.04 LTS  ami-00c70b245f5354c0a
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
