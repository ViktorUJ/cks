output "role_arn" {
  value = aws_iam_role.fluentbit_irsa.arn
}

output "role_name" {
  value = aws_iam_role.fluentbit_irsa.name
}

output "log_group_name" {
  value = local.log_group_name
}
