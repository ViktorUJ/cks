output "worker_pc_ip" {
  value = var.debug_output  == "true" ? local.worker_pc_ip  : null
}

output "worker_pc_ssh" {
  value = "   ssh ubuntu@${local.worker_pc_ip} password= ${random_string.ssh.result}   "
}

output "ssh_user" {
  value = var.debug_output  == "true" ? "ubuntu"  : null
}

output "ssh_password" {
  value = var.debug_output  == "true" ? random_string.ssh.result  : null
}

output "node_type" {
  value =var.debug_output  == "true" ?   var.work_pc.node_type  : null
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
  value = var.debug_output  == "true" ?  var.s3_k8s_config   : null
}

output "ami_id" {
  value = var.debug_output  == "true" ?  local.master_ami : null
}

output "aws_eks_cluster_eks_cluster_arn" {
  value = var.debug_output  == "true" ?  var.aws_eks_cluster_eks_cluster_arn  : null
}

output "instance_type" {
  value = var.debug_output  == "true" ?  var.work_pc.instance_type : null
}

output "kubectl_version" {
  value =  var.debug_output  == "true" ?  var.work_pc.util.kubectl_version  : null
}

output "prefix" {
  value = var.debug_output  == "true" ? local.prefix : null
}

output "app_name" {
  value =var.debug_output  == "true" ? var.app_name  : null
}

output "ec2_key" {
  value = var.work_pc.key_name
}

output "hosts_list" {
  value = var.debug_output  == "true" ? local.hosts : null
}

output "ssh_password_enable" {
  value =var.debug_output  == "true" ? var.ssh_password_enable : null
}