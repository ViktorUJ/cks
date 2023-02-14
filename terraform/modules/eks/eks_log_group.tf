resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.aws}-${var.prefix}-eks/cluster"
  retention_in_days = var.cloudwatch_retention_in_days
}