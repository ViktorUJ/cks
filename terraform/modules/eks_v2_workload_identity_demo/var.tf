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
  description = "EKS cluster name, used as a predictable prefix for created resources"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the cluster IAM OIDC identity provider (for IRSA trust policy)"
}

variable "irsa" {
  type = object({
    namespace            = string
    service_account_name = string
  })
  description = "Namespace and ServiceAccount name that the IRSA role trust policy is scoped to"
}

variable "tags" {
  type    = map(string)
  default = {}
}
