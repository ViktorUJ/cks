provider "aws" {
  region  = var.region
  profile = var.aws
}
provider "aws_cmdb" {
  region = var.region_cmdb
}