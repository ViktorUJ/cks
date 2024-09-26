locals {
  region            = "eu-north-1"
  vpc_default_cidr  = "10.10.0.0/16"
  aws    = "default"
  prefix = "awsgame-03"
  tags = {
    "env_name"        = "awsgame-03"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }

  subnets = {
    public = {
       "pub1" = {
        name = "public"
        cidr = "10.10.1.0/24"
        az   = "eu-north-1a"
      }
    }
    private = {
       "pub1" = {
        name = "app-intra-1"
        cidr = "10.10.2.0/24"
        az   = "eu-north-1a"
        nat_gateway="DEFAULT"
        type="app"
      }
       "pub2" = {
        name = "app-intra-2"
        cidr = "10.10.3.0/24"
        az   = "eu-north-1b"
        nat_gateway="SINGLE"
        type="app"
      }
       "pub3" = {
        name = "app-intra-3"
        cidr = "10.10.4.0/24"
        az   = "eu-north-1c"
        nat_gateway="SINGLE"
        type="app"
      }


    }
  }
}
