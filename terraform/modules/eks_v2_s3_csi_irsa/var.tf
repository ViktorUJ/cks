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
variable "oidc_provider_arn" {
  type = string
}
variable "tags" {
  type = map(string)
}

variable "addon_version" {
  type = string
  # Best-guess default for the aws-mountpoint-s3-csi-driver managed addon version.
  # Verify before production use:
  #   aws eks describe-addon-versions --addon-name aws-mountpoint-s3-csi-driver
  default     = "v1.15.0-eksbuild.1"
  description = "Version of the aws-mountpoint-s3-csi-driver managed addon"
}
