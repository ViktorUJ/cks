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
variable "vpc_id" {
  type = string
}
variable "zone_domain" {
  type        = string
  description = "Domain name of the private Route 53 hosted zone created for this lab"
}
variable "cert_common_name" {
  type        = string
  description = "Common name (host) of the self-signed certificate imported into ACM"
}
variable "tags" {
  type = map(string)
}
