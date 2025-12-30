# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/tests/eks-fargate-profile/main.tf

# Get VPC CIDR block by VPC ID
data "aws_vpc" "eks_vpc" {
  id = var.eks.vpc_id
}


resource "aws_security_group" "eks_api_access" {
  name        = "${var.eks.name}-eks-api-access"
  description = "Allow access to EKS ${var.eks.name}  API server"
  vpc_id      = var.eks.vpc_id

  ingress {
    description = "Allow access from env CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.api_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


module "eks" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source     = "terraform-aws-modules/eks/aws"
  version    = "21.10.1"

  name                   = var.eks.name
  kubernetes_version     = var.eks.version
  endpoint_public_access = true
  endpoint_private_access = true # Enable private access from all VPC subnets

  vpc_id                   = var.eks.vpc_id
  subnet_ids               = var.eks.subnet_ids
  control_plane_subnet_ids = var.eks.control_plane_subnet_ids

  create_security_group      = true
  create_node_security_group = true
  enable_cluster_creator_admin_permissions = true

  tags = var.eks.tags

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.eks.name
  }
}
