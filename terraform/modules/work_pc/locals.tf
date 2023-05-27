locals {
  subnets_az = distinct(split(",", (var.subnets_az)))
  subnets    = [for item in local.subnets_az : split("=", item)[0]]
  az         = [for item in local.subnets_az : split("=", item)[1]]
  tags_app   = {
    "Name"     = "${var.aws}-${var.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all       = merge(var.tags_common, local.tags_app)
  tags_k8_master = {
    "k8_node_type" = "worker-pc"
    "Name"         = "${var.aws}-${var.prefix}-${var.app_name}-worker-pc"
  }
tags_all_k8_master_x = merge(local.tags_all, local.tags_k8_master)

tags_all_k8_master = var.work_pc.node_type == "spot" ? local.tags_all_k8_master_x : ""
worker_pc_ip = var.work_pc.node_type == "spot" ? aws_spot_instance_request.master["enable"].public_ip : aws_instance.master["enable"].public_ip

}



