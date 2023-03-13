locals {
  region = "eu-west-1"
  aws= "default"
  prefix="devops"
   tags={
     "env_name"="dev"
     "env_type"="dev"
     "manage"="terraform"
     "cost_allocation"="dev"
     "owner" = "viktaruj@gmail.com"
   }
}