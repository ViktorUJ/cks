provider "aws" {
  region = var.region
}

provider "aws_cmdb" {
  region = var.region_cmdb
}
