output "role_arn" {
  value = aws_iam_role.eso_irsa.arn
}

output "role_name" {
  value = aws_iam_role.eso_irsa.name
}

output "secret_arn" {
  value = aws_secretsmanager_secret.demo.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.demo.name
}
