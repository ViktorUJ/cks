resource "aws_eks_node_group" "common" {
  cluster_name    = aws_eks_cluster.eks-cluster.name
  node_group_name = "common"
  node_role_arn   = aws_iam_role.eks-node.arn
  subnet_ids      = local.subnets
  instance_types  = var.eks_node_common_type
  labels = {
    group_type = "common"
  }
  tags = {
    "Name" = "${var.aws}-${var.prefix}-eks_workers_common"
  }
  scaling_config {
    desired_size = var.eks_node_common_desired_size
    max_size     = var.eks_node_common_max_size
    min_size     = var.eks_node_common_min_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-node-AmazonEC2ContainerRegistryReadOnly
  ]
}