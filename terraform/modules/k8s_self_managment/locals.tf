locals {
  prefix_id="${var.USER_ID}_${var.ENV_ID}"
  prefix="${local.prefix_id}_${var.prefix}"
  item_id_lock ="CMDB_${var.USER_ID}_${var.ENV_ID}_lock_${var.app_name}_${var.prefix}"
  item_id_data="CMDB_${var.USER_ID}_${var.ENV_ID}_data_${var.app_name}_${var.prefix}"
  subnets_az = distinct(split(",", (var.subnets_az)))
  subnets    = [for item in local.subnets_az : split("=", item)[0]]
  az         = [for item in local.subnets_az : split("=", item)[1]]
  tags_app   = {
    "Name"     = "${var.aws}-${local.prefix}-${var.app_name}"
    "app_name" = var.app_name
  }
  tags_all       = merge(var.tags_common, local.tags_app)
  tags_k8_master = {
    "k8_node_type" = "master"
    "Name"         = "${var.aws}-${local.prefix}-${var.app_name}-master"
  }
  tags_all_k8_master = var.node_type == "spot" ? merge(local.tags_all, local.tags_k8_master) : {}

  tags_k8_worker = {
    "k8_node_type" = "worker"
    "Name"         = "${var.aws}-${local.prefix}-${var.app_name}-worker"
  }
  tags_all_k8_worker = merge(local.tags_all, local.tags_k8_worker)
  worker_join        = "${var.s3_k8s_config}/config/${var.USER_ID}/${var.ENV_ID}/${var.cluster_name}-${local.target_time_stamp}/worker_join"
  k8s_config         = "${var.s3_k8s_config}/config/${var.USER_ID}/${var.ENV_ID}/${var.cluster_name}-${local.target_time_stamp}/config"

  worker_nodes = var.node_type == "spot" ? {
    for key, instance in data.aws_instances.spot_fleet_worker :
    key => {
      private_ip     = join("", instance.private_ips)
      public_ip      = join("", instance.public_ips)
      runtime        = var.k8s_worker[key].runtime
      labels         = var.k8s_worker[key].node_labels
      id             = join("", instance.ids)
      ami            = aws_launch_template.worker["${key}"].image_id
      ubuntu_version = var.k8s_worker["${key}"].ubuntu_version
      instance_type       = var.k8s_worker["${key}"].instance_type
    }
  } : {
    for key, instance in aws_instance.worker :
    key => {
      private_ip     = instance.private_ip
      public_ip      = instance.public_ip
      runtime        = var.k8s_worker[key].runtime
      labels         = var.k8s_worker[key].node_labels
      id             = instance.id
      ami            = instance.ami
      ubuntu_version = var.k8s_worker["${key}"].ubuntu_version
      instance_type       = var.k8s_worker["${key}"].instance_type
    }
  }

  worker_node_ids = join(" ", [for node in local.worker_nodes : node.id])
  worker_node_ips_public = join(" ", [for node in local.worker_nodes : node.public_ip])
  worker_node_ips_private = join(" ", [for node in local.worker_nodes : node.private_ip])

  master_ip           = var.node_type == "spot" ? join("", data.aws_instances.spot_fleet_master["enable"].public_ips) : aws_instance.master["enable"].public_ip
  master_ip_public    = var.k8s_master.eip == "true" ? aws_eip.master["enable"].public_ip : local.master_ip
  external_ip         = var.k8s_master.eip == "true" ? aws_eip.master["enable"].public_ip : ""
  master_instance_id  = var.node_type == "spot" ? join("", data.aws_instances.spot_fleet_master["enable"].ids) : aws_instance.master["enable"].id
  master_local_ip     = var.node_type == "spot" ? join("", data.aws_instances.spot_fleet_master["enable"].private_ips) : aws_instance.master["enable"].private_ip
  k8s_worker_ondemand = var.node_type == "ondemand" ? var.k8s_worker : {}
  k8s_worker_spot     = var.node_type == "spot" ? var.k8s_worker : {}
  master_ami          = var.k8s_master.ami_id != "" ? var.k8s_master.ami_id : data.aws_ami.master.image_id
  master_instance_type       = var.k8s_master.instance_type


}
