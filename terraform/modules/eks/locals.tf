locals {
  USER_ID=var.USER_ID=="" ? "defaultUser": var.USER_ID
  ENV_ID=var.ENV_ID=="" ? "defaultId" :var.ENV_ID
  prefix_id="${local.USER_ID}_${local.ENV_ID}"
  prefix="${local.prefix_id}_${var.prefix}"
  item_id_lock ="CMDB_${local.USER_ID}_${local.ENV_ID}_lock_${var.app_name}_${var.prefix}"
  item_id_data="CMDB_${local.USER_ID}_${local.ENV_ID}_data_${var.app_name}_${var.prefix}"
  subnets            = data.aws_subnet_ids.example.ids
  availability_zones = data.aws_availability_zones.available.zone_ids

}
