output "eks_iam_app_role" {
  value = aws_iam_role.eks-app-WebIdentity.name
}
output "aws_eks_cluster" {
  value = aws_eks_cluster.eks-cluster.name
}