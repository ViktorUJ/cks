variable "region" {}
variable "aws" {}
variable "prefix" {}
variable "USER_ID" {
  type    = string
  default = "defaultUser"
}
variable "ENV_ID" {
  type    = string
  default = "defaultId"
}
variable "app_name" {}

variable "STACK_NAME" {
  type    = string
  default = ""
}

variable "STACK_TASK" {
  type    = string
  default = ""
}

variable "name" {
  type        = string
  description = "EKS cluster name, used for tags and the cmdb record"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID of the cluster where the broken security group is created"
}

variable "tags" {
  type    = map(string)
  default = {}
}
