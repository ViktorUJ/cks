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

variable "eso" {
  type = object({
    namespace            = optional(string, "external-secrets")
    service_account_name = optional(string, "external-secrets")
  })
  default     = {}
  description = "Namespace and ServiceAccount name of the External Secrets Operator controller"
}

# The module creates its own demo secret (predictable name, see secret.tf) so the whole
# lab component stays in one small module and one terragrunt apply. kms_key_arn stays a
# real input: pass a customer managed key ARN to add a kms:Decrypt statement to the role,
# or leave it null to rely on the default aws/secretsmanager key (no extra KMS permission
# needed in that case).
variable "kms_key_arn" {
  type        = string
  default     = null
  description = "ARN of the KMS key encrypting the secret, null if using the default aws/secretsmanager key"
}

variable "tags" {
  type    = map(string)
  default = {}
}
