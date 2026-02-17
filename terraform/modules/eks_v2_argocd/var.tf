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
    version                              = optional(string, "1.8.1")
    tags                                 = optional(map(string), { "owner" = "eks-karpenter" })
    namespace                            = optional(string, "adrgocd")

  })

}
