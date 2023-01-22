terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.54.0"
    }
  }
}


provider "aws" {
  profile = "default"
  region = var.region
}