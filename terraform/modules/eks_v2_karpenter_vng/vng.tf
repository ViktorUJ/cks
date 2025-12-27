resource "kubernetes_manifest" "ec2nodeclass" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
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


resource "kubernetes_manifest" "nodepool_infra" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
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
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64", "arm64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r", "z"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["3"]
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["large", "xlarge", "2xlarge", "4xlarge"]
            },
            {
              key      = "node.kubernetes.io/instance-type"
              operator = "NotIn"
              values   = ["z1d.xlarge", "z1d.metal", "z1d.large", "z1d.6xlarge", "z1d.3xlarge", "z1d.2xlarge", "z1d.12xlarge", "x1e.xlarge", "x1e.8xlarge", "x1e.4xlarge", "x1e.32xlarge", "x1e.2xlarge", "x1e.16xlarge", "x1.32xlarge", "x1.16xlarge", "t4g.xlarge", "t4g.small", "t4g.micro", "t4g.medium", "t4g.large", "t3a.micro", "r8g.xlarge", "r8g.8xlarge", "r8g.4xlarge", "r8g.2xlarge", "r8g.16xlarge", "r7g.large", "r7g.2xlarge", "r7a.xlarge", "r7a.4xlarge", "r7a.32xlarge", "r7a.24xlarge", "r7a.12xlarge", "r6i.xlarge", "r6in.4xlarge", "r6in.2xlarge", "r6i.large", "r6id.8xlarge", "r6id.4xlarge", "r6id.2xlarge", "r6id.24xlarge", "r6i.4xlarge", "r6i.2xlarge", "r6i.24xlarge", "r6g.xlarge", "r6g.medium", "r6g.large", "r6gd.xlarge", "r6gd.metal", "r6gd.large", "r6gd.8xlarge", "r6gd.4xlarge", "r6gd.2xlarge", "r6g.8xlarge", "r6g.4xlarge", "r6a.24xlarge", "r5n.xlarge", "r5n.24xlarge", "r5.large", "r5d.xlarge", "r5d.large", "r5d.8xlarge", "r5d.4xlarge", "r5d.2xlarge", "r5d.16xlarge", "r5d.12xlarge", "r5b.2xlarge", "r5.8xlarge", "r5.4xlarge", "r5.2xlarge", "r5.24xlarge", "r5.16xlarge", "r5.12xlarge", "r4.2xlarge", "r3.xlarge", "r3.4xlarge", "r3.2xlarge", "p4de.24xlarge", "p4d.24xlarge", "p3.8xlarge", "p3.2xlarge", "p3.16xlarge", "m8g.metal-48xl", "m8gd.8xlarge", "m8gd.4xlarge", "m8gd.2xlarge", "m8gd.24xlarge", "m8gd.12xlarge", "m8g.8xlarge", "m8g.4xlarge", "m8g.12xlarge", "m7i.large", "m7i-flex.4xlarge", "m7i.24xlarge", "m7gd.xlarge", "m7gd.4xlarge", "m7gd.2xlarge", "m7gd.16xlarge", "m7gd.12xlarge", "m7a.24xlarge", "m7a.16xlarge", "m6in.xlarge", "m6in.4xlarge", "m6in.2xlarge", "m6i.metal", "m6i.large", "m6id.8xlarge", "m6id.4xlarge", "m6id.2xlarge", "m6id.16xlarge", "m6i.4xlarge", "m6i.32xlarge", "m6i.2xlarge", "m6i.24xlarge", "m6g.xlarge", "m6g.medium", "m6g.large", "m6gd.xlarge", "m6gd.metal", "m6gd.medium", "m6gd.large", "m6gd.8xlarge", "m6gd.4xlarge", "m6gd.2xlarge", "m6gd.12xlarge", "m6g.8xlarge", "m6g.4xlarge", "m6g.2xlarge", "m6g.16xlarge", "m6g.12xlarge", "m6a.48xlarge", "m6a.32xlarge", "m6a.24xlarge", "m5.xlarge", "m5n.xlarge", "m5n.2xlarge", "m5.large", "m5d.xlarge", "m5d.8xlarge", "m5d.4xlarge", "m5d.24xlarge", "m5d.16xlarge", "m5d.12xlarge", "m5ad.xlarge", "m5ad.8xlarge", "m5ad.4xlarge", "m5ad.2xlarge", "m5ad.24xlarge", "m5ad.16xlarge", "m5a.4xlarge", "m5.8xlarge", "m5.4xlarge", "m5.2xlarge", "m5.24xlarge", "m5.12xlarge", "m4.2xlarge", "inf2.xlarge", "inf1.xlarge", "inf1.6xlarge", "inf1.2xlarge", "inf1.24xlarge", "im4gn.4xlarge", "i7i.metal-24xl", "i7ie.18xlarge", "i4i.2xlarge", "i4i.16xlarge", "i3.xlarge", "i3.metal", "i3.large", "i3en.12xlarge", "i3.8xlarge", "i3.4xlarge", "i3.2xlarge", "i3.16xlarge", "i2.xlarge", "i2.8xlarge", "i2.4xlarge", "i2.2xlarge", "gr6f.4xlarge", "g6.xlarge", "g6f.4xlarge", "g6e.xlarge", "g6e.8xlarge", "g6e.4xlarge", "g6e.48xlarge", "g6e.2xlarge", "g6e.24xlarge", "g6e.16xlarge", "g6e.12xlarge", "g6.4xlarge", "g6.48xlarge", "g6.2xlarge", "g6.24xlarge", "g6.16xlarge", "g6.12xlarge", "g5.xlarge", "g5.8xlarge", "g5.4xlarge", "g5.2xlarge", "g5.24xlarge", "g5.16xlarge", "g5.12xlarge", "g4dn.8xlarge", "g4dn.4xlarge", "g4dn.2xlarge", "g4dn.16xlarge", "g4dn.12xlarge", "f1.4xlarge", "f1.2xlarge", "d2.xlarge", "d2.8xlarge", "d2.4xlarge", "d2.2xlarge", "c8g.xlarge", "c8gd.4xlarge", "c8gd.2xlarge", "c8gd.16xlarge", "c8gd.12xlarge", "c8g.8xlarge", "c8g.4xlarge", "c8g.2xlarge", "c8g.24xlarge", "c8g.16xlarge", "c8g.12xlarge", "c7i.xlarge", "c7i-flex.4xlarge", "c7i-flex.16xlarge", "c7i-flex.12xlarge", "c7i.8xlarge", "c7i.4xlarge", "c7i.12xlarge", "c7g.xlarge", "c7g.large", "c7gd.2xlarge", "c7gd.16xlarge", "c7a.xlarge", "c7a.8xlarge", "c7a.4xlarge", "c7a.2xlarge", "c7a.24xlarge", "c7a.16xlarge", "c7a.12xlarge", "c6i.xlarge", "c6in.xlarge", "c6in.metal", "c6in.8xlarge", "c6in.4xlarge", "c6in.2xlarge", "c6in.16xlarge", "c6in.12xlarge", "c6i.large", "c6id.xlarge", "c6id.8xlarge", "c6id.4xlarge", "c6id.32xlarge", "c6id.2xlarge", "c6id.24xlarge", "c6id.16xlarge", "c6id.12xlarge", "c6i.4xlarge", "c6i.24xlarge", "c6i.12xlarge", "c6g.xlarge", "c6gn.xlarge", "c6gn.large", "c6gn.8xlarge", "c6gn.4xlarge", "c6gn.2xlarge", "c6gn.12xlarge", "c6g.large", "c6gd.xlarge", "c6gd.metal", "c6gd.large", "c6gd.8xlarge", "c6gd.4xlarge", "c6gd.2xlarge", "c6gd.16xlarge", "c6gd.12xlarge", "c6a.metal", "c6a.8xlarge", "c6a.4xlarge", "c6a.48xlarge", "c6a.32xlarge", "c6a.24xlarge", "c6a.16xlarge", "c6a.12xlarge", "c5.xlarge", "c5n.xlarge", "c5n.metal", "c5n.large", "c5n.9xlarge", "c5n.4xlarge", "c5n.2xlarge", "c5n.18xlarge", "c5.metal", "c5.large", "c5d.9xlarge", "c5d.4xlarge", "c5d.2xlarge", "c5d.24xlarge", "c5d.18xlarge", "c5d.12xlarge", "c5ad.xlarge", "c5ad.8xlarge", "c5ad.4xlarge", "c5ad.24xlarge", "c5ad.16xlarge", "c5a.8xlarge", "c5a.4xlarge", "c5a.24xlarge", "c5a.16xlarge", "c5a.12xlarge", "c5.9xlarge", "c5.4xlarge", "c5.2xlarge", "c5.24xlarge", "c5.18xlarge", "c5.12xlarge", "c4.xlarge", "c4.large", "c4.8xlarge", "c4.4xlarge", "c4.2xlarge", "a1.xlarge", "a1.medium", "a1.large", "a1.4xlarge", "a1.2xlarge", "t4g.2xlarge", "t3a.xlarge", "t3a.small", "t3a.medium", "t2.micro", "r8g.metal-48xl", "r8g.metal-24xl", "r8gd.8xlarge", "r8g.12xlarge", "r7iz.metal-32xl", "r7iz.8xlarge", "r7iz.4xlarge", "r7g.xlarge", "r7g.4xlarge", "r7a.metal-48xl", "r7a.large", "r7a.8xlarge", "r6in.xlarge", "r6id.xlarge", "r6idn.24xlarge", "r6gd.medium", "r6g.2xlarge", "r6a.large", "r6a.48xlarge", "r6a.32xlarge", "r5.xlarge", "r5n.2xlarge", "r5dn.24xlarge", "r5d.metal", "r5d.24xlarge", "r5b.24xlarge", "r3.large", "m8g.large", "m8gd.16xlarge", "m8g.2xlarge", "m7i.xlarge", "m7i.metal-48xl", "m7gd.large", "m7gd.8xlarge", "m7g.2xlarge", "m7a.metal-48xl", "m7a.8xlarge", "m6i.xlarge", "m6in.metal", "m6id.xlarge", "m6idn.2xlarge", "m6id.24xlarge", "m6i.8xlarge", "m6i.12xlarge", "m6g.metal", "m6a.metal", "m6a.large", "m6a.4xlarge", "m6a.2xlarge", "m5n.large", "m5d.2xlarge", "m5a.2xlarge", "m5a.12xlarge", "i7ie.metal-48xl", "i4i.12xlarge", "i3en.2xlarge", "g6.8xlarge", "g4dn.metal", "g4ad.2xlarge", "g4ad.16xlarge", "dl2q.24xlarge", "c8g.metal-24xl", "c8g.medium", "c7i-flex.8xlarge", "c7i.2xlarge", "c7gd.8xlarge", "c7gd.4xlarge", "c7a.metal-48xl", "c7a.large", "c6in.24xlarge", "c6i.8xlarge", "c6i.32xlarge", "c6i.2xlarge", "c6i.16xlarge", "c6g.12xlarge", "c6a.2xlarge", "c5d.xlarge", "c5d.large", "c5ad.12xlarge", "c3.large", "c3.8xlarge", "t3.micro", "r8g.medium", "r8g.large", "r8gd.metal-24xl", "r7i.metal-48xl", "r7i.24xlarge", "r7g.8xlarge", "r7a.2xlarge", "r6in.metal", "r6in.large", "r6idn.xlarge", "r6idn.metal", "r6id.16xlarge", "r6i.8xlarge", "r6i.16xlarge", "r6i.12xlarge", "r6g.metal", "r6gd.16xlarge", "r6gd.12xlarge", "r6a.xlarge", "r6a.metal", "r6a.4xlarge", "r5n.metal", "r5n.large", "r5n.4xlarge", "r5n.12xlarge", "r5b.xlarge", "r5b.16xlarge", "r5b.12xlarge", "r4.xlarge", "r3.8xlarge", "m8g.xlarge", "m8g.metal-24xl", "m8gd.xlarge", "m8gd.metal-24xl", "m8g.16xlarge", "m7i-flex.16xlarge", "m7i-flex.12xlarge", "m7i.2xlarge", "m7gd.metal", "m7a.xlarge", "m7a.4xlarge", "m7a.2xlarge", "m7a.12xlarge", "m6idn.xlarge", "m6idn.metal", "m6id.large", "m6id.12xlarge", "m6i.16xlarge", "m6gd.16xlarge", "m6a.xlarge", "m6a.8xlarge", "m6a.16xlarge", "m5n.4xlarge", "m5a.xlarge", "m5ad.large", "m5a.24xlarge", "m5a.16xlarge", "m5.16xlarge", "m4.xlarge", "m4.4xlarge", "m4.16xlarge", "m3.2xlarge", "is4gen.8xlarge", "im4gn.8xlarge", "i8g.metal-24xl", "i8g.12xlarge", "i7ie.metal-24xl", "i4i.metal", "i4i.4xlarge", "i4i.32xlarge", "gr6.4xlarge", "g6f.2xlarge", "g4dn.xlarge", "d3en.8xlarge", "d3en.12xlarge", "c8g.large", "c8gd.metal-24xl", "c8gd.large", "c7i.large", "c7i.24xlarge", "c7gd.xlarge", "c7gd.metal", "c7gd.12xlarge", "c7g.12xlarge", "c7a.32xlarge", "c6in.large", "c6in.32xlarge", "c6i.metal", "c6id.metal", "c6id.large", "c6gn.medium", "c6g.4xlarge", "c6g.2xlarge", "c6a.xlarge", "c5d.metal", "c5ad.large", "c5ad.2xlarge", "c5a.2xlarge", "c3.4xlarge", "c3.2xlarge"]
            }
          ]
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "infra-v1"
          }
          expireAfter = "7200h"
          #  taints = [
          #    {
          #      key    = "dedicated"
          #      value  = "karpenter"
          #      effect = "NoSchedule"
          #    }
          #  ]
        }
      }

      limits = {
        cpu = 200
      }

      disruption = {
        budgets = [
          {
            nodes = "30%"
          }
        ]
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "600s"
      }
    }
  }
}



/*

resource "kubernetes_manifest" "nodepool" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
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
          requirements = var.requirements
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = kubernetes_manifest.ec2nodeclass.manifest.metadata.name
          }
          expireAfter = var.nodepool.expireAfter

        }
      }

      limits = var.nodepool.limits

      disruption = {
        budgets             = var.disruption.budgets
        consolidationPolicy = var.disruption.consolidationPolicy
        consolidateAfter    = var.disruption.consolidateAfter
      }
    }
  }
}



*/
