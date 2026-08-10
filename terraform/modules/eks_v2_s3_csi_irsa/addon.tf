resource "aws_eks_addon" "s3_csi" {
  cluster_name                = var.name
  addon_name                  = "aws-mountpoint-s3-csi-driver"
  addon_version               = var.addon_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.s3_csi_irsa.arn
}
