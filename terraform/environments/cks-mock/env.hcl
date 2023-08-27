locals {
  region = "eu-north-1"
  aws= "default"
  prefix="cks-mock"
   tags={
     "env_name"="cks-mock"
     "env_type"="dev"
     "manage"="terraform"
     "cost_allocation"="dev"
     "owner" = "viktoruj@gmail.com"
   }
}