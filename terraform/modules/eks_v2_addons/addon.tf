resource "aws_eks_addon" "addons" {
  for_each          = var.addons
  cluster_name      = var.cluster
  addon_name        = each.key
  addon_version     = each.value.version
  resolve_conflicts_on_create = each.value.resolve_conflicts
  resolve_conflicts_on_update=each.value.resolve_conflicts
  dynamic "configuration_values" {
    for_each = each.value.configuration != null && each.value.configuration != {} ? [1] : []
    content {
      configuration_values = jsonencode(each.value.configuration)
    }
  }
}
