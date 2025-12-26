resource "aws_eks_addon" "addons" {
  cluster_name      = var.name
  addon_name        = var.name
  addon_version     = var.addons.name
  resolve_conflicts_on_create = var.addons.resolve_conflicts
  resolve_conflicts_on_update=var.addons.resolve_conflicts
  configuration_values = (
    try(var.addons.configuration, null) != null && try(var.addons.configuration, {}) != {} ?
    jsonencode(var.addons.configuration) :
    null
  )
}
