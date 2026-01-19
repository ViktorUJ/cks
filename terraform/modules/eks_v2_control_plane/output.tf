output "kubectl_config" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.eks.name} "
}
output "eks_mudule" {
  value = module.eks
}

output "name" {
  value = var.eks.name
}
output "additional_IP_cirds" {
  value = local.api_cidr
}