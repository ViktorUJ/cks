output "kubectl_config" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.eks.name} "
}