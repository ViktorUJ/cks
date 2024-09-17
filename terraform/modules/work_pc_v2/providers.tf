provider "aws" {
  region = var.region
}
provider "aws" {
  region = var.region_cmdb
  alias  = "cmdb"

}
