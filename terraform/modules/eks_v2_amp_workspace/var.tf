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

variable "alias" {
  type        = string
  description = "Alias of the AMP workspace, used by the worker to find it without reading terraform output"
}

variable "tags" {
  type    = map(string)
  default = {}
}
