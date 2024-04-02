locals {
  region                 = "asia-east2-a"
  backend_region         = "ASIA-EAST2"
  backend_bucket         = "v0v4n-cks-state-backet"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "gcs" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.40"
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
  backend = "gcs"
  config  = {
    bucket         = local.backend_bucket
    location       = local.backend_region
    prefix         = "terragrunt${path_relative_to_include()}"
  }
}
inputs = {
 region = local.backend_region
 backend_bucket=local.backend_bucket
 backend_dynamodb_table=local.backend_dynamodb_table
}
