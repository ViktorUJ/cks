output "eks_iam_app_role" {
  value = aws_iam_role.eks-app-WebIdentity.name
}
output "eks_cluster_name" {
  value = aws_eks_cluster.eks-cluster.name
}
output "aws_eks_cluster_eks_cluster_arn" {
  value = aws_eks_cluster.eks-cluster.arn
}