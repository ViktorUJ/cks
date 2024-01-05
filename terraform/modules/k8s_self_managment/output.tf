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

output "master_ssh" {
  value = "ssh ubuntu@${local.master_ip_public}  password= ${random_string.ssh.result}  "
}

output "eip" {
  value = var.k8s_master.eip
}

output "check_node_status" {
  value = "tail -f /var/log/cloud-init-output.log "
}

output "s3_k8s_config" {
  value = local.k8s_config
}

output "worker_nodes" {
  value = local.worker_nodes
}

output "ami_id_master" {
  value = local.master_ami
}

output "master_instance_type" {
  value = local.master_instance_type
}

output "worker_reload_bashrc" {
  value = "  source ~/.bashrc   "
}
output "ec2_key" {
  value = var.k8s_master.key_name
}

output "ssh_password" {
  value = "  ${random_string.ssh.result}   "
}

output "hosts_worker_node" {
  value = local.hosts_worker_node
}
output "hosts_master_node" {
  value = local.hosts_master_node
}

output "hosts" {
  value = local.hosts
}