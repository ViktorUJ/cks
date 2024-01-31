provider "aws" {
  region  = var.region
  profile = var.aws
}
provider "aws" {
  alias = "cmdb"
  region = var.region_cmdb
}