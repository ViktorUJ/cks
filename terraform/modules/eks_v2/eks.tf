# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/tests/eks-fargate-profile/main.tf

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

  create_security_group      = true
  create_node_security_group = true


  tags = var.eks.tags

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.eks.name
  }
}


