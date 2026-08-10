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
  type = object({
    name              = string
    version           = string
    resolve_conflicts = optional(string, "OVERWRITE")
    configuration     = optional(any)
  })
}
variable "name" {
  type = string
}
variable "oidc_provider_arn" {
  type = string
}
variable "tags" {
  type = map(string)
}
variable "vpc_id" {
  type = string
}
# Приватные подсети, по одной на каждую AZ, где нужен mount target EFS.
variable "subnet_ids" {
  type = list(string)
}
# Security group нод кластера - ей разрешаем inbound NFS (2049) на mount target.
variable "security_group_source_id" {
  type = string
}
