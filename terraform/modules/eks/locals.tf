locals {
  prefix_id="${var.USER_ID}_${var.ENV_ID}"
  prefix="${local.prefix_id}_${var.prefix}"
  item_id_lock ="CMDB_${var.USER_ID}_${var.ENV_ID}_lock_${var.app_name}_${var.prefix}"
  item_id_data="CMDB_${var.USER_ID}_${var.ENV_ID}_data_${var.app_name}_${var.prefix}"
  subnets            = data.aws_subnet_ids.example.ids
  availability_zones = data.aws_availability_zones.available.zone_ids

}
