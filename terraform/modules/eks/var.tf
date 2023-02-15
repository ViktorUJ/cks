variable "region" {}
variable "aws" {} # aws cli profile_name
variable "prefix" {}
variable "vpc_id" {}

variable "eks" {type = object({
  version = string
  cloudwatch_retention_in_days = string
  allow_cidrs=list(string)
  node_group = map(object({
    ec2_types=list(string)
    capacity_type = string  # ON_DEMAND, SPOT
    desired_size = string
    max_size = string
    min_size = string
    labels = map(string)
  }))

})}