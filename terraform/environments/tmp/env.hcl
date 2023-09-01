locals {
  region = "eu-north-1"
  aws= "default"
  prefix="eks"
   tags={
     "env_name"="eks"
     "env_type"="dev"
     "manage"="terraform"
     "cost_allocation"="dev"
     "owner" = "viktoruj@gmail.com"
   }
}
