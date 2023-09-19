locals {
  subnets_az = distinct(split(",", (var.subnets_az)))
  subnets    = [for item in local.subnets_az : split("=", item)[0]]
  az         = [for item in local.subnets_az : split("=", item)[1]]
  tags_app = {
    "Name"     = "${var.aws}-${var.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all = merge(var.tags_common, local.tags_app)
  tags_k8_master = {
    "k8_node_type" = "master"
    "Name"         = "${var.aws}-${var.prefix}-${var.app_name}-master"
  }
  tags_all_k8_master = var.node_type == "spot" ? merge(local.tags_all, local.tags_k8_master) : {}

  tags_k8_worker = {
    "k8_node_type" = "worker"
    "Name"         = "${var.aws}-${var.prefix}-${var.app_name}-worker"
  }
  tags_all_k8_worker = merge(local.tags_all, local.tags_k8_worker)
  worker_join        = "${var.s3_k8s_config}/${var.cluster_name}-${local.target_time_stamp}/worker_join"
  k8s_config         = "${var.s3_k8s_config}/${var.cluster_name}-${local.target_time_stamp}/config"

 # worker_ip={}
  worker_ip = var.node_type == "spot" ? [
    for k, v in data.aws_instances.spot_fleet_worker :
    "${k} private_ip = join('',${v.private_ips})  public_ip = join('',${v.public_ips})  runtime = ${var.k8s_worker[k].runtime} labels= ${var.k8s_worker[k].node_labels} "
    ] : [
    for k, v in aws_instance.worker :
    "${k} private_ip = ${v.private_ip}  public_ip = ${v.public_ip}  runtime = ${var.k8s_worker[k].runtime} labels= ${var.k8s_worker[k].node_labels} "
  ]

  master_ip           = var.node_type == "spot" ? join("",data.aws_instances.spot_fleet_master["enable"].public_ips) : aws_instance.master["enable"].public_ip
  master_ip_public    = var.k8s_master.eip == "true" ? aws_eip.master["enable"].public_ip : local.master_ip
  external_ip         = var.k8s_master.eip == "true" ? aws_eip.master["enable"].public_ip : ""
  master_instance_id  = var.node_type == "spot" ? data.aws_instances.spot_fleet_master["enable"].id : aws_instance.master["enable"].id
  master_local_ip     = var.node_type == "spot" ? join("",data.aws_instances.spot_fleet_master["enable"].private_ips) : aws_instance.master["enable"].private_ip
  k8s_worker_ondemand = var.node_type == "ondemand" ? var.k8s_worker : {}
  k8s_worker_spot     = var.node_type == "spot" ? var.k8s_worker : {}
}
