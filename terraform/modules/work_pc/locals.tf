locals {
  USER_ID      = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID       = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix_id    = "${local.USER_ID}_${local.ENV_ID}"
  prefix       = "${local.prefix_id}_${var.prefix}"
  item_id_lock = "CMDB_lock_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  item_id_data = "CMDB_data_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  subnets_az   = distinct(split(",", (var.subnets_az)))
  subnets      = [for item in local.subnets_az : split("=", item)[0]]
  az           = [for item in local.subnets_az : split("=", item)[1]]
  worker_pc_ssh= var.ssh_password_enable=="true" ? "   ssh ubuntu@${local.worker_pc_ip} password= ${random_string.ssh.result}   " : "   ssh ubuntu@${local.worker_pc_ip}   "
  tags_app = {
    "Name"     = "${local.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all = merge(var.tags_common, local.tags_app)
  tags_k8_master = {
    "k8_node_type" = "worker-pc"
    "Name"         = "${local.prefix}-${var.app_name}-worker-pc"
  }
  tags_all_k8_master = var.work_pc.node_type == "spot" ? merge(local.tags_all, local.tags_k8_master) : {}

  worker_pc_ip = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].public_ips) : aws_instance.master["enable"].public_ip
  master_ami   = var.work_pc.ami_id != "" ? var.work_pc.ami_id : data.aws_ami.master.image_id
  worker_pc_id = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].ids) : aws_instance.master["enable"].id
  hosts        = join(" ", var.host_list)
}
