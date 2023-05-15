output "worker_pc_ip" {
  value = aws_spot_instance_request.master.public_ip
}

output "worker_pc_ssh" {
  value = "   ssh ubuntu@${aws_spot_instance_request.master.public_ip}  "
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

