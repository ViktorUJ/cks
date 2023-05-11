output "worker_pc_ip" {
  value = aws_eip.master.public_ip
}

output "worker_pc_ssh" {
  value = "   ssh ubuntu@${aws_eip.master.public_ip}  "
}


output "worker_pc" {
  value = "   tail -f /var/log/cloud-init-output.log    "
}

output "worker_reload_bashrc" {
  value = "  source ~/.bashrc   "
}