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
  description = "EKS cluster name"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the managed node group"
}

variable "mng" {
  type = object({
    name           = string
    instance_types = optional(list(string), ["t3.medium"])
    ami_type       = optional(string, "AL2023_x86_64_STANDARD")
    capacity_type  = optional(string, "ON_DEMAND")
    min_size       = optional(number, 1)
    max_size       = optional(number, 2)
    desired_size   = optional(number, 1)
    labels         = optional(map(string), {})
    tags           = optional(map(string), {})
  })
  description = "Settings for the healthy baseline managed node group of this lab"
}
