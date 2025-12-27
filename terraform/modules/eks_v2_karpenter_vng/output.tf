output "vng" {
  value = var.vng
}
output "nodepool" {
  value = var.nodepool
}
output "requirements" {
  value = var.requirements
}
output "disruption" {
  value = var.disruption

}
output "kubectl_config" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.name} "
}
output "budgets" {
  value = var.budgets
}