
module "karpenter" {
  depends_on   = [aws_dynamodb_table_item.cmdb_data]
  source       = "terraform-aws-modules/eks/aws//modules/karpenter"
  version      = "21.10.1"
  cluster_name = var.name
  namespace    = var.karpenter.namespace
  # Additional permissions for Karpenter to work properly
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }

  tags = var.karpenter.tags
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter.version
  namespace        = var.karpenter.namespace
  create_namespace = true
  wait             = false

  set = [
      {
      name  = "logLevel"
      value = "debug"
    },
    {
      name  = "settings.clusterName"
      value = var.name
    },
    {
      name  = "settings.interruptionQueue"
      value = module.karpenter.queue_name
    },
    {
      name  = "controller.resources.requests.cpu"
      value = "1"
    },
    {
      name  = "controller.resources.requests.memory"
      value = "1Gi"
    },
    {
      name  = "controller.resources.limits.cpu"
      value = "1"
    },
    {
      name  = "controller.resources.limits.memory"
      value = "1Gi"
    },
    {
      name  = "replicas"
      value = var.karpenter.replicas
    },
  ]
}
