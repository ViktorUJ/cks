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
    # EKS Auto Mode (глава 9). По умолчанию null - режим выключен, поведение модуля не
    # меняется для всех лаб, которые этот параметр не передают. При enabled = true
    # передаётся напрямую в compute_config блока aws_eks_cluster через upstream-модуль
    # terraform-aws-modules/eks/aws: node_pools задаёт встроенные NodePool ("system",
    # "general-purpose"), которые редактировать нельзя, только включать/отключать.
    compute_config = optional(object({
      enabled       = bool
      node_pools    = optional(list(string))
      node_role_arn = optional(string)
    }), null)
    # Режим авторизации кластера (глава 5, лаба 102). По умолчанию null - используется
    # дефолт upstream-модуля terraform-aws-modules/eks/aws ("API_AND_CONFIG_MAP"), как и
    # раньше для всех лаб, которые этот параметр не передают. Лаба 102 передаёт "API"
    # явно, чтобы учить access entries без aws-auth ConfigMap.
    authentication_mode = optional(string, null)
  })
}