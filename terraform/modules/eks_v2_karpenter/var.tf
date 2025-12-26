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
    namespace                            = optional(string, "karpenter")
    irsa_oidc_provider_arn               = optional(string, "")
    serviceAccount_create                = optional(string, "true")
    serviceAccount_name                  = optional(string, "karpenter")
    logLevel                             = optional(string, "info")
    controller_resources_requests_cpu    = optional(string, "1")
    controller_resources_requests_memory = optional(string, "1Gi")
    controller_resources_limits_cpu      = optional(string, "1")
    controller_resources_limits_memory   = optional(string, "1Gi")
    controller_replicas                  = optional(string, "2")

  })

}
