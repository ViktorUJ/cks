data "aws_eks_cluster" "this" {
  name = var.name
}
data "aws_iam_openid_connect_provider" "this" {
  arn = var.oidc_provider_arn
}