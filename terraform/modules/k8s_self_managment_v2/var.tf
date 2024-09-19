variable "region" {}
variable "aws" {}
variable "prefix" {}
variable "tags_common" {
  type = map(string)
}
variable "USER_ID" {
  type    = string
  default = "defaultUser"
}
variable "ENV_ID" {
  type    = string
  default = "defaultId"
}
variable "app_name" {}
variable "vpc_id" {}
variable "subnets" {
  type = list(string)
}
# k8_version    https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages
variable "cluster_name" { type = string }
variable "time_sleep" {
  default = "30s"
}
variable "ssh_password_enable" {
  default = "true"
}
variable "node_type" { type = string }
variable "k8s_master" {
  type = object({
    instance_type      = string
    ami_id             = string
    ubuntu_version     = string
    key_name           = string
    cidrs              = list(string)
    subnet_number      = string
    user_data_template = string
    k8_version         = string
    runtime            = string
    runtime_script     = string
    utils_enable       = string
    pod_network_cidr   = string
    cni=optional(object({
      type = optional(string, "calico") # calico, cilium
      calico_url = optional(string, "https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml")
      cilium_version = optional(string, "v1.16.1")

    }),{})
    task_script_url    = string # url for run additional script
    eip                = string # true or ...
    ssh = object({
      private_key = string
      pub_key     = string
    })
    root_volume = object({
      type = string
      size = string
    })
  })
}

variable "k8s_worker" {
  type = map(object({
    instance_type      = string
    ami_id             = string
    ubuntu_version     = string
    key_name           = string
    cidrs              = list(string)
    subnet_number      = string
    user_data_template = string
    k8_version         = string
    runtime            = string
    runtime_script     = string
    task_script_url    = string # url for run additional script
    node_labels        = string
    ssh = object({
      private_key = string
      pub_key     = string
    })
    root_volume = object({
      type = string
      size = string
    })
  }))
}

variable "STACK_NAME" {
  type    = string
  default = ""
}

variable "STACK_TASK" {
  type    = string
  default = ""
}
