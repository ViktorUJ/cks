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

variable "eks" {
  type = object({
    name        = string
    version     = string
    vpc_id= string
    eks_access_cidr= optional(list(string),[])
    subnet_ids  = list(string)
    control_plane_subnet_ids= list(string)
    tags        = map(string)
  })
}