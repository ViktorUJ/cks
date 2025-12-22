module "eks" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source     = "terraform-aws-modules/eks/aws"
  version    = "21.10.1"

  name               = var.eks.name
  kubernetes_version = var.eks.version
  addons = {
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      configuration_values = jsonencode({
        computeType = "Fargate"
      })
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  # Optional
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
