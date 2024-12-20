locals {
  region            = "eu-north-1"
  vpc_default_cidr  = "10.10.0.0/16"
  aws    = "default"
  prefix = "awsgame-07"
  tags = {
    "env_name"        = "awsgame-07"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }

  subnets = {
    public = {
       "pub1" = {
        name = "public-1"
        cidr = "10.10.1.0/24"
        az   = "eu-north-1a"
      }
       "pub2" = {
        name = "public-2"
        cidr = "10.10.2.0/24"
        az   = "eu-north-1b"
      }
       "pub3" = {
        name = "public-3"
        cidr = "10.10.3.0/24"
        az   = "eu-north-1c"
      }
    }


    private = {}
  }
}