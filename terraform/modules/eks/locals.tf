locals {
  prefix_id="${var.USER_ID}_${var.ENV_ID}"
  prefix=local.prefix_id == "_" ? var.prefix : local.prefix_id
  subnets            = data.aws_subnet_ids.example.ids
  availability_zones = data.aws_availability_zones.available.zone_ids

}
