output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}

output "secret_arn" {
  value = aws_secretsmanager_secret.demo.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.demo.name
}

output "irsa_role_arn" {
  value = aws_iam_role.irsa.arn
}

output "irsa_role_name" {
  value = aws_iam_role.irsa.name
}

output "pod_identity_role_arn" {
  value = aws_iam_role.pod_identity.arn
}

output "pod_identity_role_name" {
  value = aws_iam_role.pod_identity.name
}
