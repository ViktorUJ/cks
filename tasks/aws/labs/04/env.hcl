locals {
  region            = "eu-north-1"
  vpc_default_cidr  = "10.10.0.0/16"
  aws    = "default"
  prefix = "awsgame-04"
  tags = {
    "env_name"        = "awsgame-04"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }

  subnets = {
    public = {}
    private = {
       "pub2" = {
        name = "app"
        cidr = "10.10.2.0/24"
        az   = "eu-north-1b"
        nat_gateway="NONE"
      }
    }
  }
}
