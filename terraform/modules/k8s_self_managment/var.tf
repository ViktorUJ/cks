variable "region" {}
variable "aws" {}
variable "prefix" {}
variable "tags_common" {
  type = map(string)
}
variable "app_name" {}
variable "vpc_id" {}
variable "subnets_az" {}
variable "s3_k8s_config" {}
# k8_version    https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages
variable "k8s_master" {
  type = object({
    instance_type      = string
    ami_id             = string
    key_name           = string
    cidrs              = list(string)
    subnet_number      = string
    user_data_template = string
    k8_version         = string
    runtime            = string
    runtime_script     = string
    utils_enable       = string
    task_script_enable = string
    task_script_file   = string
    pod_network_cidr   = string
    root_volume        = object({
      type = string
      size = string
    })
  })
}

variable "k8s_worker" {
  type = map(object({
    instance_type      = string
    ami_id             = string
    key_name           = string
    cidrs              = list(string)
    subnet_number      = string
    user_data_template = string
    k8_version         = string
    runtime            = string
    runtime_script     = string
    root_volume        = object({
      type = string
      size = string
    })
  }))
}



