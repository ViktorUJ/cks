# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/tests/eks-fargate-profile/main.tf

# Get VPC CIDR block by VPC ID
data "aws_vpc" "eks_vpc" {
  id = var.eks.vpc_id
}

module "eks" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source     = "terraform-aws-modules/eks/aws"
  version    = "21.10.1"

  name                   = var.eks.name
  kubernetes_version     = var.eks.version
  endpoint_public_access = true

  vpc_id                   = var.eks.vpc_id
  subnet_ids               = var.eks.subnet_ids
  control_plane_subnet_ids = var.eks.control_plane_subnet_ids

  # Allow access to EKS API from VPC CIDR
  cluster_endpoint_private_access_cidrs = [data.aws_vpc.eks_vpc.cidr_block]

  create_security_group      = true
  create_node_security_group = true
  enable_cluster_creator_admin_permissions = true

  tags = var.eks.tags

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.eks.name
  }
}
