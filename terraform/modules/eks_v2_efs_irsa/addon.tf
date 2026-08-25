
resource "aws_eks_addon" "addons" {
  cluster_name                = var.name
  addon_name                  = var.addons.name
  addon_version               = var.addons.version
  resolve_conflicts_on_create = var.addons.resolve_conflicts
  resolve_conflicts_on_update = var.addons.resolve_conflicts
  service_account_role_arn    = aws_iam_role.efs_csi_irsa.arn
  configuration_values = (
    try(var.addons.configuration, null) != null && length(try(var.addons.configuration, {})) > 0 ?
    jsonencode(var.addons.configuration) :
    null
  )

  depends_on = [aws_efs_mount_target.this]
}
