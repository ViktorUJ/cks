# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/tests/eks-fargate-profile/main.tf

module "eks" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1"

  name                   = var.eks.name
  kubernetes_version     = var.eks.version
  endpoint_public_access = true
  endpoint_private_access = true # Enable private access from all VPC subnets

  vpc_id                   = var.eks.vpc_id
  subnet_ids               = var.eks.subnet_ids
  control_plane_subnet_ids = var.eks.control_plane_subnet_ids

  create_security_group                    = true
  create_node_security_group = true
  # cluster_additional_security_group_ids = [aws_security_group.eks_api_access.id]
  enable_cluster_creator_admin_permissions = true

  tags = var.eks.tags

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.eks.name
  }


  cluster_security_group_additional_rules = {
    private_api_from_vpc_and_peers = {
      description = "Allow EKS private endpoint (443) from VPC + peered VPCs"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = local.api_cidr
    }
  }
}
