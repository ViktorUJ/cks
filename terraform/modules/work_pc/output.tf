output "worker_pc_ip" {
  value = local.worker_pc_ip
}

output "worker_pc_ssh" {
  value = "   ssh ubuntu@${local.worker_pc_ip}  "
}
output "node_type" {
  value = var.work_pc.node_type
}

output "worker_pc" {
  value = "   tail -f /var/log/cloud-init-output.log    "
}

output "worker_reload_bashrc" {
  value = "  source ~/.bashrc   "
}

output "checking_time" {
  value = "  time_left   "
}

output "checking_result" {
  value = "  check_result   "
}

output "backup_kube_config" {
  value = "  /home/ubuntu/.kube/_config   "
}

output "s3_k8s_config" {
  value = var.s3_k8s_config
}

output "eks_cluster_name" {
  value = var.eks_cluster_name
}