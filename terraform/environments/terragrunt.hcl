#generate "backend" {
#  path      = "backend.tf"
#  if_exists = "overwrite_terragrunt"
#  contents = <<EOF
#remote_state {
#  backend = "s3"
#  config = {
#    bucket         = "viktoruj-terraform-state-backet"
#    key            = "terragrunt${path_relative_to_include()}/terraform.tfstate"
#    region         = "eu-north-1"
#    encrypt        = true
#    dynamodb_table = "viktoruj-terraform-state-backet-lock"
#  }
#EOF
#}
#

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.54.0"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "viktoruj-terraform-state-backet"
    key            = "terragrunt${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "viktoruj-terraform-state-backet-lock"
  }
}