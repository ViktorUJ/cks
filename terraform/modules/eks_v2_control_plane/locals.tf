locals {
  USER_ID            = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID             = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix_id          = "${local.USER_ID}_${local.ENV_ID}"
  prefix             = "${local.prefix_id}_${var.prefix}"
  item_id_lock       = "CMDB_lock_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  item_id_data       = "CMDB_data_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  name="${var.prefix}-${var.USER_ID}-${var.ENV_ID}-${var.STACK_NAME}-${var.STACK_TASK}"

}
