resource "aws_eks_node_group" "groups" {
  for_each        = var.eks.node_group
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.eks-node.arn
  subnet_ids      = local.subnets
  instance_types  = each.value.ec2_types
  capacity_type   = each.value.capacity_type
  labels          = each.value.labels
  disk_size       = each.value.disk_size
  tags = {
    "Name" = "${local.prefix}-eks_workers_${each.key}"
  }
  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly
  ]
}
