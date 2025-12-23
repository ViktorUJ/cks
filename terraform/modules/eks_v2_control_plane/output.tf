output "kubectl_config" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.eks.name} "
}
output "eks_mudule_output" {
  value = module.eks.outputs
}