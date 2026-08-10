# Managed node group used as a healthy baseline for lab 119 (troubleshooting a
# node that does not reach Ready). EKS creates the EC2_LINUX access entry for this
# node role automatically, so `aws eks describe-nodegroup` and the node itself stay
# healthy - the failure scenario is reproduced separately with a self-managed
# instance that intentionally skips the access entry step.

resource "aws_iam_role" "node" {
  name = "${local.prefix}-${var.mng.name}-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = var.mng.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_node_group" "healthy" {
  cluster_name    = var.name
  node_group_name = "${local.prefix}-${var.mng.name}"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.mng.instance_types
  ami_type        = var.mng.ami_type
  capacity_type   = var.mng.capacity_type
  labels          = var.mng.labels
  tags            = var.mng.tags

  scaling_config {
    min_size     = var.mng.min_size
    max_size     = var.mng.max_size
    desired_size = var.mng.desired_size
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_cni,
    aws_dynamodb_table_item.cmdb_data,
  ]
}
