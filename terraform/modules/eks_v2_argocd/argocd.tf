
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
      value = var.karpenter.controller_replicas
    },
    {
      name  = "settings.featureGates.kubeletConfiguration"
      value = var.karpenter.featureGates_kubeletConfiguration
    },
    {
      name  = "settings.featureGates.spotToSpotConsolidation"
      value = var.karpenter.featureGates_spotToSpotConsolidation
    }
  ]
}
