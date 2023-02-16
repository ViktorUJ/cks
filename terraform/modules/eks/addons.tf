resource "aws_eks_addon" "addons" {
  for_each          = var.eks.addons
  cluster_name      = aws_eks_cluster.eks-cluster.id
  addon_name        = each.key
  addon_version     = each.value.version
  resolve_conflicts = each.value.resolve_conflicts
}