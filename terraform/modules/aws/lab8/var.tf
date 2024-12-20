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
variable "tags_common" {
  type = map(string)
}
variable "app_name" {}
variable "vpc_id" {}

variable "time_sleep" {
  default = "30s"
}
variable "STACK_NAME" {
  type    = string
  default = ""
}

variable "STACK_TASK" {
  type    = string
  default = ""
}

variable "subnets" {
  type = list(string)
}
variable "subnets_private" {
    type = list(string)
}
variable "ami" {
  default = "ami-0d916634f7eb5727f"

}
variable "instance_type" {
    default = "t4g.small"
}
variable "volume_size" {
    default = 8
}
variable "volume_type" {
    default="gp3"
}
variable "asg" {
  type = object({
    min_size         = string
    max_size         = string
    desired_capacity = string
  })
  default = {
    min_size         = 1
    max_size         = 4
    desired_capacity = 1
  }
}
variable "vpc_default_cidr" {}

variable "notification_email" {
  default = "viktoruj@gmail.com"
}