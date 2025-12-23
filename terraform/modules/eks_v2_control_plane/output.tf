output "kubectl_config" {
  value = "aws eks update-kubeconfig --region ${var.region} --name ${var.eks.name} "
}
output "eks_mudule" {
  value = module.eks
}

output "ebs_csi_iam" {
  value = aws_iam_role.ebs_csi.arn
}
