output "role_arn" {
  value = aws_iam_role.lbc_irsa.arn
}

output "role_name" {
  value = aws_iam_role.lbc_irsa.name
}
