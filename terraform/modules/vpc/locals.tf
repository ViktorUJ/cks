locals {
  USER_ID=var.USER_ID=="" ? "defaultUser": var.USER_ID
  ENV_ID=var.ENV_ID=="" ? "defaultId" :var.ENV_ID
  prefix_id="${local.USER_ID}_${local.ENV_ID}"
  prefix="${local.prefix_id}_${var.prefix}"
  item_id_lock ="CMDB_${local.USER_ID}_${local.ENV_ID}_lock_${var.app_name}_${var.prefix}"
  item_id_data="CMDB_${local.USER_ID}_${local.ENV_ID}_data_${var.app_name}_${var.prefix}"
  subnets_az = [
    for x in aws_subnet.subnets_pub :
  "${x.id}=${x.availability_zone}"]
  subnets_az_cmdb = join(",", local.subnets_az)
  tags_app = {
    "Name"     = "${local.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all = merge(var.tags_common, local.tags_app)

}
