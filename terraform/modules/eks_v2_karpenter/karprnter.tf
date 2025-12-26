resource "aws_iam_policy" "karpenter_controller_instance_profiles" {
  name        = "${var.name}-karpenter-controller-instanceprofiles"
  description = "Karpenter controller permissions for instance profile GC"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InstanceProfileGC"
        Effect = "Allow"
        Action = [
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = "*"
      }
    ]
  })
}


module "karpenter" {
  depends_on   = [aws_dynamodb_table_item.cmdb_data]
  source       = "terraform-aws-modules/eks/aws//modules/karpenter"
  version      = "20.8.5"
  cluster_name = var.name
  irsa_oidc_provider_arn          = var.karpenter.irsa_oidc_provider_arn
  irsa_namespace_service_accounts = ["${var.karpenter.namespace}:karpenter"]
  enable_irsa                     = true

  # Additional permissions for Karpenter to work properly
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  }

  tags = var.karpenter.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_instance_profiles" {
  role       = module.karpenter.iam_role_name
  policy_arn = aws_iam_policy.karpenter_controller_instance_profiles.arn
}


resource "helm_release" "karpenter" {
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter.version
  namespace        = var.karpenter.namespace
  create_namespace = var.karpenter.controller_create_namespace
  wait             = var.karpenter.controller_wait_ready_pods

  set = [

       {
      name  = "serviceAccount.create"
      value = var.karpenter.serviceAccount_create
    },
    {
      name  = "serviceAccount.name"
      value = var.karpenter.serviceAccount_name
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.karpenter.iam_role_arn
    },

      {
      name  = "logLevel"
      value = var.karpenter.logLevel
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
      value = var.karpenter.controller_resources_requests_cpu
    },
    {
      name  = "controller.resources.requests.memory"
      value = var.karpenter.controller_resources_requests_memory
    },
    {
      name  = "controller.resources.limits.cpu"
      value = var.karpenter.controller_resources_limits_cpu
    },
    {
      name  = "controller.resources.limits.memory"
      value = var.karpenter.controller_resources_limits_memory
    },
    {
      name  = "replicas"
      value = var.karpenter.replicas
    },
  ]
}
