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
    version           = string
    resolve_conflicts = optional(string, "OVERWRITE")
    # configuration - простая карта, где ВСЕ значения одного типа. Из-за optional(any)
    # terraform обязан свести типы всех элементов addons к общему, поэтому смешивать
    # внутри configuration плоские значения и вложенные блоки нельзя: получите
    # "Unsuitable value for var.addons ... cannot find a common base type for all
    # elements" (поймано на лабе 126, где к env добавили init.env).
    configuration = optional(any, {})
    # Для вложенных схем (например init.env.DISABLE_TCP_EARLY_DEMUX у vpc-cni) передавайте
    # готовый JSON строкой: configuration_json = jsonencode({ env = {...}, init = {...} }).
    # Тип string сводится всегда, поэтому проблемы выше не возникает.
    configuration_json = optional(string)
  }))
}
variable "name" {
    type = string
}