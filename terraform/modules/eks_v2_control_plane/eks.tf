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


  security_group_additional_rules = {
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

# CoreDNS runs on Fargate and uses the EKS *primary* cluster security group
# (cluster.resourcesVpcConfig.clusterSecurityGroupId), NOT the additional cluster SG
# managed by `security_group_additional_rules`. Pods on Karpenter EC2 nodes use the node
# security group. These rules allow those pods to reach CoreDNS (DNS 53 TCP/UDP) on Fargate.
resource "aws_vpc_security_group_ingress_rule" "nodes_to_fargate_dns_udp" {
  security_group_id            = module.eks.cluster_primary_security_group_id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "udp"
  description                  = "DNS UDP from Karpenter nodes to CoreDNS on Fargate"
}

resource "aws_vpc_security_group_ingress_rule" "nodes_to_fargate_dns_tcp" {
  security_group_id            = module.eks.cluster_primary_security_group_id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 53
  to_port                      = 53
  ip_protocol                  = "tcp"
  description                  = "DNS TCP from Karpenter nodes to CoreDNS on Fargate"
}

# Pods on Fargate (including the kubelet that serves their metrics) use the EKS
# *primary* cluster security group, while Prometheus runs on Karpenter EC2 nodes and
# sources traffic from the node security group. By default there is no rule permitting
# the node SG to reach the primary SG on the kubelet port, so scrapes of Fargate pods
# time out ("context deadline exceeded"). This rule allows Prometheus to scrape the
# kubelet (10250) of pods running on Fargate.
resource "aws_vpc_security_group_ingress_rule" "nodes_to_fargate_kubelet" {
  security_group_id            = module.eks.cluster_primary_security_group_id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 10250
  to_port                      = 10250
  ip_protocol                  = "tcp"
  description                  = "Kubelet metrics scrape from Karpenter nodes to Fargate pods"
}

# CoreDNS exposes Prometheus metrics on 9153/TCP (separate from DNS on 53). Since CoreDNS
# runs on Fargate (primary cluster SG) and Prometheus runs on Karpenter EC2 nodes (node SG),
# scrapes of the CoreDNS metrics endpoint time out without an explicit rule. This allows
# Prometheus to scrape CoreDNS metrics (9153) on Fargate.
resource "aws_vpc_security_group_ingress_rule" "nodes_to_fargate_coredns_metrics" {
  security_group_id            = module.eks.cluster_primary_security_group_id
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 9153
  to_port                      = 9153
  ip_protocol                  = "tcp"
  description                  = "CoreDNS metrics scrape from Karpenter nodes to Fargate pods"
}
