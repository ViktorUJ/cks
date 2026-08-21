data "aws_iam_openid_connect_provider" "this" {
  arn = var.oidc_provider_arn
}

data "aws_caller_identity" "current" {}
