resource "kubernetes_manifest" "ec2nodeclass" {
  depends_on   = [aws_dynamodb_table_item.cmdb_data]
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = var.vng.name
    }
    spec = {
      role = var.vng.iam_role
      amiSelectorTerms = [
        { alias = var.vng.ami_alias }
      ]

      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.name
          }
        }
      ]

      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.name
          }
        }
      ]


      tags = merge(var.vng.tags, { "Name" = "${var.name}-${var.vng.name}" })

      blockDeviceMappings = var.vng.blockDeviceMappings
      kubelet = {
        systemReserved = {
          cpu                 = "100m"  # Resources reserved for system processes. Recommended: 100m-500m depending on node size
          memory              = "0.5Gi" # Memory reserved for system daemons. Recommended: 0.5-2Gi or 5-10% of total memory
          "ephemeral-storage" = "1Gi"   # Storage reserved for system use. Recommended: 1-10Gi based on disk size
        }
        kubeReserved = {
          cpu                 = "0.1"   # Resources reserved for Kubernetes system daemons. Recommended: 0.1-1 core based on node type
          memory              = "0.5Gi" # Memory reserved for k8s components. Recommended: 0.5-2Gi or 5-10% of total memory
          "ephemeral-storage" = "1Gi"   # Storage reserved for k8s components. Recommended: 1-10Gi based on disk size
        }
        evictionHard = {
          "memory.available"   = "5%" # Hard eviction threshold for available memory. Recommended: 5-15% or at least 500Mi
          "nodefs.available"   = "5%" # Hard eviction threshold for node filesystem. Recommended: 5-15% or at least 10Gi
          "nodefs.inodesFree"  = "5%" # Hard eviction threshold for node inodes. Recommended: 5-10%
          "imagefs.available"  = "5%" # Hard eviction threshold for image filesystem. Recommended: 5-15% or at least 5Gi
          "imagefs.inodesFree" = "5%" # Hard eviction threshold for image filesystem inodes. Recommended: 5-10%
          "pid.available"      = "5%" # Hard eviction threshold for process IDs. Recommended: 5-10%
        }
        evictionSoft = {
          "memory.available"   = "10%" # Soft eviction threshold for available memory. Recommended: 10-20% or at least 1Gi
          "nodefs.available"   = "10%" # Soft eviction threshold for node filesystem. Recommended: 10-20% or at least 15Gi
          "nodefs.inodesFree"  = "10%" # Soft eviction threshold for node inodes. Recommended: 10-15%
          "imagefs.available"  = "10%" # Soft eviction threshold for image filesystem. Recommended: 10-20% or at least 10Gi
          "imagefs.inodesFree" = "10%" # Soft eviction threshold for image filesystem inodes. Recommended: 10-15%
          "pid.available"      = "10%" # Soft eviction threshold for process IDs. Recommended: 10-15%
        }
        evictionSoftGracePeriod = {
          "memory.available"   = "1m" # Grace period for soft memory eviction. Recommended: 1-5m
          "nodefs.available"   = "1m" # Grace period for soft nodefs eviction. Recommended: 1-5m
          "nodefs.inodesFree"  = "1m" # Grace period for soft nodefs inodes eviction. Recommended: 1-5m
          "imagefs.available"  = "1m" # Grace period for soft imagefs eviction. Recommended: 1-5m
          "imagefs.inodesFree" = "1m" # Grace period for soft imagefs inodes eviction. Recommended: 1-5m
          "pid.available"      = "1m" # Grace period for soft PID eviction. Recommended: 1-5m
        }
        evictionMaxPodGracePeriod = 120 # Maximum grace period to wait before force terminating pods. Recommended: 30-300 seconds
      }


    }
  }
}


resource "kubernetes_manifest" "nodepool" {
  depends_on   = [aws_dynamodb_table_item.cmdb_data]
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = var.vng.name
    }
    spec = {
      template = {
        metadata = {
          labels = {
            work_type = var.vng.name
          }
        }
        spec = {
          requirements = var.vng.nodepool.requirements
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = kubernetes_manifest.ec2nodeclass.manifest.metadata.name
          }
          expireAfter = var.vng.nodepool.expireAfter

        }
      }

      limits = var.vng.nodepool.limits

      disruption = var.vng.nodepool.disruption
    }
  }
}

