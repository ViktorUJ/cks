variable "region" {}
variable "az_ids" {
  type = map(string)
}

variable "vpc_default_cidr" {}

variable "aws" {}
variable "prefix" {}
variable "app_name" {}
variable "USER_ID" {
  type = string
  default = ""
}
variable "ENV_ID" {
  type = string
  default = ""
}
variable "tags_common" {
  type = map(string)
}
