# Get VPC CIDR block by VPC ID
data "aws_vpc" "eks_vpc" {
  id = var.eks.vpc_id
}