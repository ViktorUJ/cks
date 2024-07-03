locals {
  USER_ID       = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID        = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  prefix_id     = "${local.USER_ID}_${local.ENV_ID}"
  prefix        = "${local.prefix_id}_${var.prefix}"
  password      = var.ssh_password_enable ? random_string.ssh["enabled"].result : null
  item_id_lock  = "CMDB_lock_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  item_id_data  = "CMDB_data_${local.USER_ID}_${local.ENV_ID}_${var.app_name}_${var.prefix}"
  subnets_az    = distinct(split(",", (var.subnets_az)))
  subnets       = [for item in local.subnets_az : split("=", item)[0]]
  az            = [for item in local.subnets_az : split("=", item)[1]]
  worker_pc_ssh = var.ssh_password_enable ? "   ssh ubuntu@${local.worker_pc_ip} password= ${random_string.ssh["enabled"].result}   " : "   ssh ubuntu@${local.worker_pc_ip}   "
  tags_app = {
    "Name"     = "${local.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all = merge(var.tags_common, local.tags_app)

  worker_pc_ip = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].public_ips) : aws_instance.master["enable"].public_ip
  master_ami   = var.work_pc.ami_id != "" ? var.work_pc.ami_id : data.aws_ami.master.image_id
  worker_pc_id = var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].ids) : aws_instance.master["enable"].id
  hosts = [
    "${var.work_pc.hostname}=${var.work_pc.node_type == "spot" ? join("", data.aws_instances.spot_fleet["enable"].private_ips) : aws_instance.master["enable"].public_ip}"
  ]
  user_data = base64encode(templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(var.work_pc.user_data_template, {
      ssh_private_key     = var.work_pc.ssh.private_key
      ssh_pub_key         = var.work_pc.ssh.pub_key
      exam_time_minutes   = var.work_pc.exam_time_minutes
      test_url            = var.work_pc.test_url
      task_script_url     = var.work_pc.task_script_url
      ssh_password        = local.password
      ssh_password_enable = var.ssh_password_enable
      hostname            = var.work_pc.hostname
      hosts               = join(" ", var.host_list)
    }))
  }))
}
