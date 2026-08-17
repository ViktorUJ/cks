resource "aws_eks_addon" "addons" {
  for_each          = var.addons
  cluster_name      = var.name
  addon_name        = each.key
  addon_version     = each.value.version
  resolve_conflicts_on_create = each.value.resolve_conflicts
  resolve_conflicts_on_update=each.value.resolve_conflicts
  # configuration_json имеет приоритет: он нужен для схем с вложенными блоками, которые
  # нельзя выразить через configuration (см. комментарий у переменной addons).
  configuration_values = (
    try(each.value.configuration_json, null) != null ?
    each.value.configuration_json :
    (
      try(each.value.configuration, null) != null && length(try(each.value.configuration, {})) > 0 ?
      jsonencode(each.value.configuration) :
      null
    )
  )
}
