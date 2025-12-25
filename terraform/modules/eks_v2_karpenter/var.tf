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
    type = string
}

variable "karpenter" {
  type = object({
    version = optional(string,"1.7.1")
    tags = optional(map(string),{"owner" = "eks task2"})
    namespace= optional(string,"kerpenter")
  })
  default = {
    version = "0.29.5"
    namespace = "kerpenter"
    tags = {
      "owner" = "eks task2"
    }

  }
}