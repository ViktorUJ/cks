output "role_arn" {
  value = aws_iam_role.irsa.arn
}

output "role_name" {
  value = aws_iam_role.irsa.name
}

output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}
