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
  description = "EKS cluster name, used to build the predictable CloudWatch log group name"
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the cluster IAM OIDC identity provider (for IRSA trust policy)"
}

# Namespace and ServiceAccount name match the defaults of the aws-for-fluent-bit Helm chart
# (aws/eks-charts), so the annotation added by the student at install time lines up with the
# trust policy `sub` condition without any extra flags. log_group_name defaults to the
# convention used in chapter 34: /aws/eks/<cluster>/application.
variable "fluent_bit" {
  type = object({
    namespace            = optional(string, "amazon-cloudwatch")
    service_account_name = optional(string, "aws-for-fluent-bit")
    log_group_name       = optional(string, null)
  })
  default     = {}
  description = "Namespace, ServiceAccount name and target log group of the Fluent Bit DaemonSet"
}

variable "tags" {
  type    = map(string)
  default = {}
}
