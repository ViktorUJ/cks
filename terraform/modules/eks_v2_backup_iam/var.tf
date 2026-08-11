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

variable "tags" {
  type = map(string)
}

# Имя кластера EKS (env_name), а не просто prefix: делает имена роли и vault уникальными
# между параллельными окружениями стенда, как у остальных *_irsa модулей (lbc_irsa, ebs_irsa).
variable "name" {
  type = string
}
