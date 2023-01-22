variable "region" {}
variable "az_ids" {
   type = map(string)
}

variable "vpc_default_cidr" {}

variable "aws" {}
variable "prefix" {}
variable "app_name" {}

variable "tags_common" {
   type = map(string)
}
