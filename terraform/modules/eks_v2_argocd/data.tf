
data "aws_eks_cluster" "this" {
  name       = var.name
}

data "aws_eks_cluster_auth" "this" {
  name       = var.name
}
