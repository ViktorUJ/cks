locals {
  prefix_id="${var.USER_ID}_${var.ENV_ID}"
  prefix=local.prefix_id == "_" ? var.prefix : local.prefix_id
  item_id_lock =local.prefix_id == "_" ? "CMDB_defaultUser_defaultId_lock_${var.prefix}" : "CMDB_${var.USER_ID}_${var.ENV_ID}_lock_${var.prefix}_workPc"
  item_id_data=local.prefix_id == "_" ? "CMDB_defaultUser_defaultId_data_${var.prefix}" : "CMDB_${var.USER_ID}_${var.ENV_ID}_data_${var.prefix}_workPc"
  subnets_az = distinct(split(",", (var.subnets_az)))
  subnets    = [for item in local.subnets_az : split("=", item)[0]]
  az         = [for item in local.subnets_az : split("=", item)[1]]
  tags_app   = {
    "Name"     = "${var.aws}-${local.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all       = merge(var.tags_common, local.tags_app)
  tags_k8_master = {
    "k8_node_type" = "worker-pc"
    "Name"         = "${var.aws}-${local.prefix}-${var.app_name}-worker-pc"
  }
  tags_all_k8_master = var.work_pc.node_type == "spot" ? merge(local.tags_all, local.tags_k8_master) : {}

  worker_pc_ip = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].public_ips) : aws_instance.master["enable"].public_ip
  master_ami   = var.work_pc.ami_id != "" ? var.work_pc.ami_id : data.aws_ami.master.image_id
  worker_pc_id  = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].ids) : aws_instance.master["enable"].id
}
