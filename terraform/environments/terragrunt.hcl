remote_state {
  backend = "s3"
  config = {
    bucket         = "viktoruj-terraform-state-backet_new"
    key            = "terragrunt${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "viktoruj-terraform-state-backet-lock_new"
  }
}