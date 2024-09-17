output "worker_pc_ip" {
  value = var.debug_output == "true" ? local.worker_pc_ip : null
}

output "worker_pc_ssh" {
  value = local.worker_pc_ssh
}

output "ssh_user" {
  value = var.debug_output == "true" ? "ubuntu" : null
}

output "ssh_password" {
  value = var.debug_output == "true" ? random_string.ssh.result : null
}

output "node_type" {
  value = var.debug_output == "true" ? var.work_pc.node_type : null
}

output "boot_log" {
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
  value = var.debug_output == "true" ? var.s3_k8s_config : null
}

output "ami_id" {
  value = var.debug_output == "true" ? local.master_ami : null
}

output "aws_eks_cluster_eks_cluster_arn" {
  value = var.debug_output == "true" ? var.aws_eks_cluster_eks_cluster_arn : null
}

output "instance_type" {
  value = var.debug_output == "true" ? var.work_pc.instance_type : null
}

output "kubectl_version" {
  value = var.debug_output == "true" ? var.work_pc.util.kubectl_version : null
}

output "prefix" {
  value = var.debug_output == "true" ? local.prefix : null
}

output "app_name" {
  value = var.debug_output == "true" ? var.app_name : null
}

output "ec2_key" {
  value = length(var.work_pc.key_name) > 0 ? var.work_pc.key_name : null
}

output "hosts_list" {
  value = var.debug_output == "true" ? local.hosts : null
}

output "ssh_password_enable" {
  value = var.debug_output == "true" ? var.ssh_password_enable : null
}

output "arch" {
  value = var.debug_output == "true" ? local.arch : null
}

output "questions_list" {
  value = length(var.questions_list) > 0 ? "   ${var.questions_list}    " : null
}

output "ssh_access_cidrs" {
  value = var.debug_output == "true" ? var.work_pc.cidrs : null
}

output "solutions_scripts" {
  value = length(var.solutions_scripts) > 0 ? "   ${var.solutions_scripts}    " : null
}

output "solutions_video" {
  value = length(var.solutions_video) > 0 ? "   ${var.solutions_video}    " : null
}
