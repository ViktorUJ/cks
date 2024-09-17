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
variable "subnets" {
  type = list(string)
}
variable "time_sleep" {
  default = "30s"
}
variable "aws_eks_cluster_eks_cluster_arn" {
  default = ""
}
variable "ssh_password_enable" {
  default = "true"
}
variable "debug_output" {
  default = "false" # false | true
}
variable "questions_list" {
  default = ""
}

variable "solutions_scripts" {
  default = ""
}

variable "solutions_video" {
  default = ""
}

variable "work_pc" {
  type = object({
    clusters_config    = map(string)
    instance_type      = string
    ami_id             = string
    key_name           = string
    cidrs              = list(string)
    subnet_number      = string
    ubuntu_version     = string
    user_data_template = string
    task_script_url    = string # url for run additional script
    node_type          = string # spot ar ondemand
    ssh = object({
      private_key = string
      pub_key     = string
    })
    test_url          = string
    exam_time_minutes = string
    util = object({
      kubectl_version = string
    })
    root_volume = object({
      type = string
      size = string
    })
    non_root_volumes = map(object({
      delete_on_termination = optional(bool),
      size                  = number,
      type                  = string,
      encrypted             = optional(bool)
    }))
  })
}

variable "STACK_NAME" {
  type    = string
  default = ""
}

variable "STACK_TASK" {
  type    = string
  default = ""
}

variable "host_list" {
  type    = list(string)
  default = []
}
