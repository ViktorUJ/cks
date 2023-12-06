locals {
  prefix_id="${var.USER_ID}_${var.ENV_ID}"
  prefix=local.prefix_id == "_" ? var.prefix : local.prefix_id
  item_id_lock =local.prefix_id == "_" ? "CMDB_defaultUser_defaultId_lock_${var.prefix}" : "CMDB_${var.USER_ID}_${var.ENV_ID}_lock_${var.prefix}"
  item_id_data=local.prefix_id == "_" ? "CMDB_defaultUser_defaultId_data_${var.prefix}" : "CMDB_${var.USER_ID}_${var.ENV_ID}_data_${var.prefix}"
  subnets_az = [
    for x in aws_subnet.subnets_pub :
  "${x.id}=${x.availability_zone}"]
  subnets_az_cmdb = join(",", local.subnets_az)
  tags_app = {
    "Name"     = "${var.aws}-${local.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all = merge(var.tags_common, local.tags_app)

}
