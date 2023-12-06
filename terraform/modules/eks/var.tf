variable "region" {}
variable "aws" {}
variable "prefix" {}
variable "USER_ID" {
  type = string
  default = ""
}
variable "ENV_ID" {
  type = string
  default = ""
}
variable "vpc_id" {}
variable "app_name" {}

variable "eks" {
  type = object({
    version                      = string
    cloudwatch_retention_in_days = string
    allow_cidrs                  = list(string)
    addons = map(object({
      # key  - addon name
      version           = string
      resolve_conflicts = string # OVERWRITE

    }))
    node_group = map(object({
      ec2_types     = list(string)
      capacity_type = string # ON_DEMAND, SPOT
      desired_size  = string
      max_size      = string
      min_size      = string
      labels        = map(string)
      disk_size     = string
    }))

  })
}
