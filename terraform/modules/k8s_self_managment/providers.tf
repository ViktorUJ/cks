provider "aws" {
  region = var.region
}

provider "aws" {
  alias = "cmdb"
  region = var.region_cmdb
}
