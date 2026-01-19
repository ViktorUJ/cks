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
variable "addons" {
  type = map(object({
  version=string
  resolve_conflicts=optional(string, "OVERWRITE")
  configuration= optional(any)
  }))
}
variable "name" {
    type = string
}