output "bucket_name" {
  value = aws_s3_bucket.mountpoint_demo.bucket
}

output "role_arn" {
  value = aws_iam_role.s3_csi_irsa.arn
}

output "addon" {
  value = aws_eks_addon.s3_csi
}
