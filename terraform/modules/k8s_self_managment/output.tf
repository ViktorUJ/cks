output "master_external_ip" {
  value = local.external_ip
}

output "cluster" {
  value = var.cluster_name
}
output "master_local_ip" {
  value = local.master_local_ip
}
#output "master_ec2_id" {
#  value = aws_spot_instance_request.master.spot_instance_id
#}
#output "master_ec2_ebs_id" {
#  value = aws_spot_instance_request.master.root_block_device[0].volume_id
#}
output "worker_join" {
  value = "s3://${local.worker_join}"
}

output "k8s_config" {
  value = "s3://${local.k8s_config}"
}
output "k8_master_version" {
  value = var.k8s_master.k8_version
}
output "worker_ip" {
  value = local.worker_ip
}

output "master_ssh" {
  value = "ssh ubuntu@${local.external_ip}"
}


output "check_node_status" {
  value = "tail -f /var/log/cloud-init-output.log "
}

