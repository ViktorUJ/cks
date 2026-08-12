locals {
  # TODO: update the docs
  # Resolve from the parent environment directory when this config is included by a child module.
  variables_directory = dirname(find_in_parent_folders("variables.example.hcl", "${get_terragrunt_dir()}/variables.example.hcl"))
  variables_file      = fileexists("${local.variables_directory}/variables.hcl") ? "${local.variables_directory}/variables.hcl" : "${local.variables_directory}/variables.example.hcl"
  environment         = read_terragrunt_config(local.variables_file)
  region              = local.environment.locals.region
  backend_region      = local.environment.locals.backend_region
  backend_bucket      = local.environment.locals.backend_bucket
  cmdb_dynamodb_table = local.environment.locals.cmdb_dynamodb_table
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 5.17.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
  }
}
variable "s3_k8s_config" {
default="${local.backend_bucket}"
}
variable "cmdb_dynamodb_table" {
default="${local.cmdb_dynamodb_table}"
}

variable "region_cmdb" {
default="${local.backend_region}"
}

EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket       = local.backend_bucket
    key          = "terragrunt${path_relative_to_include()}/terraform.tfstate"
    region       = local.backend_region
    encrypt      = true
    use_lockfile = true
  }
}
inputs = {
  region              = local.region
  backend_bucket      = local.backend_bucket
  cmdb_dynamodb_table = local.cmdb_dynamodb_table
}
