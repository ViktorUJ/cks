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
    "k8_node_type" = "master"
    "Name"         = "${var.aws}-${var.prefix}-${var.app_name}-master"
  }
  tags_all_k8_master = merge(local.tags_all, local.tags_k8_master)

  tags_k8_worker = {
    "k8_node_type" = "worker"
    "Name"         = "${var.aws}-${var.prefix}-${var.app_name}-worker"
  }
  tags_all_k8_worker = merge(local.tags_all, local.tags_k8_worker)
  worker_join        = "${var.s3_k8s_config}/${local.target_time_stamp}/worker_join"
  k8s_config         = "${var.s3_k8s_config}/${local.target_time_stamp}/config"

  worker_ip = [
    for k, v  in aws_spot_instance_request.worker :
    "${k} private_ip = ${v.private_ip}  public_ip = ${v.public_ip}  labels= ${var.k8s_worker[k].node_labels} "
  ]

}



