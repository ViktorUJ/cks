provider "aws" {
  region = var.region
}
provider "aws" {
  region = var.region_cmdb
  alias  = "cmdb"

}
provider "aws" {
  alias = "cloudfront"
  region = "us-east-1"
}