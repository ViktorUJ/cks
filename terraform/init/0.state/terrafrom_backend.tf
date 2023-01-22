terraform {
  backend "s3" {
    bucket = "viktoruj-terraform-state-backet"
    region = "eu-north-1"
    key = "audit/infra.tfstate"
    dynamodb_table = "viktoruj-terraform-state-backet-lock"
    encrypt = true
  }
}
