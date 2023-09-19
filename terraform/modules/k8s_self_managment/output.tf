output "master_external_ip" {
  value = local.master_ip_public
}

output "cluster" {
  value = var.cluster_name
}
output "master_local_ip" {
  value = local.master_local_ip
}
output "node_type" {
  value = var.node_type
}
output "worker_join" {
  value = "s3://${local.worker_join}"
}

output "k8s_config" {
  value = "s3://${local.k8s_config}"
}
output "k8_master_version" {
  value = var.k8s_master.k8_version
}
#output "worker_ip" {
#  value = local.worker_ip
#}

output "master_ssh" {
  value = "ssh ubuntu@${local.master_ip_public}"
}

output "eip" {
  value = var.k8s_master.eip
}

output "check_node_status" {
  value = "tail -f /var/log/cloud-init-output.log "
}

output "s3_k8s_config" {
  value = var.s3_k8s_config
}

#output "worker_local_ips" {
#  value = {
#    for key, instance in data.aws_instances.spot_fleet_worker :
#    key => {
#      private_ips = join("", instance.private_ips)
#      public_ips  = join("", instance.public_ips)
#      id          = join("", instance.ids)
#      runtime     = var.k8s_worker[key].runtime
#      labels      = var.k8s_worker[key].node_labels
#    }
#  }
#}

#output "workers" {
#  value = local.workers
#}