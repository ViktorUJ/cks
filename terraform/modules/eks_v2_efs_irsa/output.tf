output "addons" {
  value = aws_eks_addon.addons
}

output "file_system_id" {
  value = aws_efs_file_system.this.id
}

output "role_arn" {
  value = aws_iam_role.efs_csi_irsa.arn
}
