include {
  path = find_in_parent_folders()
}

locals {
  vars= read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
#   source = "git::git@github.com:ViktorUJ/cks.git//terraform/modules/vpc/?ref=task_01"
    source = "../../..//modules/vpc/"
}

inputs = {
   region=local.vars.locals.region
   aws=local.vars.locals.aws
   prefix=local.vars.locals.prefix
   tags_common=local.vars.locals.tags
   app_name = "network"
   vpc_default_cidr="10.11.0.0/16"
   az_ids={
   "10.11.0.0/19"=  "euw1-az1"
   "10.11.32.0/19"= "euw1-az2"
   "10.11.64.0/19"= "euw1-az1"

  }

}
