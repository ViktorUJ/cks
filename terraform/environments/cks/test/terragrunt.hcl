include "root" {
  path = find_in_parent_folders()
  expose = true
}

#locals {
##  vars= read_terragrunt_config(find_in_parent_folders("env.hcl"))
#  vars=read_terragrunt_config(find_in_parent_folders("terragrunt.hcl"))
#}

terraform {
#   source = "git::git@github.com:ViktorUJ/cks.git//terraform/modules/vpc/?ref=task_01"
    source = "../../..//modules/test/"
}

inputs = {
   region="${include.root.inputs.region}"

  }


