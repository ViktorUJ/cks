# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/tests/eks-fargate-profile/main.tf

module "eks" {
  depends_on = [aws_dynamodb_table_item.cmdb_data]
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.1"

  name                   = var.eks.name
  kubernetes_version     = var.eks.version
  endpoint_public_access = true
  endpoint_private_access = true # Enable private access from all VPC subnets
  # Явно фиксируем access entries (не дефолт модуля): AWS Backup для EKS создаёт себе
  # access entry и читает объекты кластера через Kubernetes API только в этом режиме.
  # Лаба 102 передаёт var.eks.authentication_mode = "API", чтобы учить access entries
  # без aws-auth ConfigMap - для всех остальных лаб (var.eks.authentication_mode = null)
  # сохраняется прежнее поведение "API_AND_CONFIG_MAP".
  authentication_mode = coalesce(var.eks.authentication_mode, "API_AND_CONFIG_MAP")

  vpc_id                   = var.eks.vpc_id
  subnet_ids               = var.eks.subnet_ids
  control_plane_subnet_ids = var.eks.control_plane_subnet_ids

  # EKS Auto Mode (глава 9, лаба 125): compute_config = null по умолчанию, поэтому для
  # всех лаб, которые его не передают, upstream-модуль ведёт себя точно как раньше -
  # блок compute_config в aws_eks_cluster просто не создаётся (см. dynamic-блок в
  # terraform-aws-modules/eks/aws версии 21).
  compute_config = var.eks.compute_config

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
