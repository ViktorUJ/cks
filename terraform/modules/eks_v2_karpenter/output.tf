output "karpenter_module" {
  value = module.karpenter
}

output "kubectl_config" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.name} "
}