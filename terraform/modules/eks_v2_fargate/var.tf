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

variable "fargate" {
  type = object({
    name        = string
    subnet_ids=  list(string)
    tags        = map(string)
    selectors=list(map(string))
  })
}
variable "name" {
    type = string
}