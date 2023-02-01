locals {
  region = local.vars.locals.region
  aws= "default"
  prefix="cka1"
   tags={
     "env_name"="cka"
     "env_type"="dev"
     "manage"="terraform"
     "cost_allocation"="dev"
     "owner" = "viktaruj@gmail.com"
   }
}