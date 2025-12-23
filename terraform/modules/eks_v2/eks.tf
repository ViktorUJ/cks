# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/tests/eks-fargate-profile/main.tf

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

module "eks" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source     = "terraform-aws-modules/eks/aws"
  version    = "21.10.1"

  name                   = var.eks.name
  kubernetes_version     = var.eks.version
  endpoint_public_access = true

  addons = {
    kube-proxy = {}
    vpc-cni    = {}
    coredns = {
      configuration_values = jsonencode({
        computeType = "fargate"
      })
    }
  }

  vpc_id                   = var.eks.vpc_id
  subnet_ids               = var.eks.subnet_ids
  control_plane_subnet_ids = var.eks.control_plane_subnet_ids

  create_security_group      = true
  create_node_security_group = true

  # removed: fargate_profile_defaults (unsupported by the module you actually call)

  fargate_profiles = {
    kube-system = {
      selectors = [
        { namespace = "kube-system" }
      ]

      subnet_ids = var.eks.subnet_ids
      tags       = var.eks.tags

      # IMPORTANT: set explicitly to avoid "Invalid count argument" inside fargate-profile submodule
      partition  = data.aws_partition.current.partition
      account_id = data.aws_caller_identity.current.account_id
    }
  }

  tags = var.eks.tags

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.eks.name
  }
}


/*
module "eks" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source     = "terraform-aws-modules/eks/aws"
  version    = "21.10.1"

  name               = var.eks.name
  kubernetes_version = var.eks.version
 addons = {
    kube-proxy = {}
    vpc-cni    = {}
    coredns = {
      configuration_values = jsonencode({
        computeType = "fargate"
      })
    }
  }
    eks-pod-identity-agent = {}
    kube-proxy = {}
    vpc-cni = {}
  endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  # Enable OIDC provider for the cluster to allow IRSA
  enable_irsa = true

  vpc_id                   = var.eks.vpc_id
  subnet_ids               = var.eks.subnet_ids
  control_plane_subnet_ids = var.eks.control_plane_subnet_ids

  # Fargate profile inside module; assumes var.eks.subnet_ids are private subnets
  fargate_profiles = {
    kube_system = {
      name = "kube-system"
     create = true
     partition  = data.aws_partition.current.partition
     account_id = data.aws_caller_identity.current.account_id

      selectors = [
        { namespace = "kube-system" }
      ]
      subnet_ids = var.eks.subnet_ids
    }
  }

  tags = var.eks.tags

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.eks.name
  }
}


 */