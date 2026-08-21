output "role_arn" {
  value = aws_iam_role.vpclattice_irsa.arn
}

output "role_name" {
  value = aws_iam_role.vpclattice_irsa.name
}
