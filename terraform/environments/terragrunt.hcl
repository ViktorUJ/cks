locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "vitdevops-platform-state-backet"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
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
  }
}
variable "s3_k8s_config" {
default="${local.backend_bucket}"
}
variable "backend_dynamodb_table" {
default="${local.backend_dynamodb_table}"
}

variable "region_cmdb" {
default="${local.backend_region}"
}

EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket         = local.backend_bucket
    key            = "terragrunt${path_relative_to_include()}/terraform.tfstate"
    region         = local.backend_region
    encrypt        = true
    dynamodb_table = local.backend_dynamodb_table
  }
}
inputs = {
  region                 = local.backend_region
  backend_bucket         = local.backend_bucket
  backend_dynamodb_table = local.backend_dynamodb_table
}
