locals {
  region = "eu-north-1"
  aws= "default"
  prefix="cks1"
   tags={
     "env_name"="cks"
     "env_type"="dev"
     "manage"="terraform"
     "cost_allocation"="dev"
     "owner" = "viktoruj@gmail.com"
   }
}