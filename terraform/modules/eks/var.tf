variable "region" {}
variable "aws" {} # aws cli profile_name
variable "prefix" {}
variable "eks_version" {}
variable "vpc_id" {}

variable "eks_allow_cidrs" { type = list(string) }
variable "eks_node_common_type" { type = list(string) }
variable "eks_node_common_desired_size" {}
variable "eks_node_common_max_size" {}
variable "eks_node_common_min_size" {}
variable "eks_capacity_type" {} # ON_DEMAND, SPOT
variable "cloudwatch_retention_in_days" {}