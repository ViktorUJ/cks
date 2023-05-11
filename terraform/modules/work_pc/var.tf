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
variable "work_pc" {
  type = object({
    clusters_config    = map(string)
    instance_type      = string
    ami_id             = string
    key_name           = string
    cidrs              = list(string)
    subnet_number      = string
    user_data_template = string
    ssh                = object({
      private_key = string
      pub_key     = string
    })
    test_url=string
    exam_time_minutes = string
    util              = object({
      kubectl_version = string
    })
    root_volume = object({
      type = string
      size = string
    })
  })
}




