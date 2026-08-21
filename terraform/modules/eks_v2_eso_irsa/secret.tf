# Secrets Manager secret for the lab. Name is predictable (prefix based), so the worker
# can find it by name without reading terraform output. Encrypted with the default
# aws/secretsmanager key unless kms_key_arn overrides it.
resource "aws_secretsmanager_secret" "demo" {
  name       = local.secret_name
  kms_key_id = var.kms_key_arn
  tags       = merge(var.tags, { "Name" = local.secret_name })
}

resource "aws_secretsmanager_secret_version" "demo" {
  secret_id = aws_secretsmanager_secret.demo.id
  secret_string = jsonencode({
    username = "appuser"
    password = "S3cr3tPass123"
  })
}
