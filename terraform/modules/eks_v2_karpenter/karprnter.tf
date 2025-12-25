
module "karpenter" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source     = "terraform-aws-modules/eks/aws//modules/karpenter"
  version    = "21.10.1"
  cluster_name = var.name

  # Additional permissions for Karpenter to work properly
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }

  tags = var.karpenter.tags
}

