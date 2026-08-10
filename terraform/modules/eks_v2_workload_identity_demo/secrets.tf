# Secrets Manager secret used by the Pod Identity demo pod. Name is predictable (prefix +
# app_name), so the worker can find it by name without reading terraform output.
resource "aws_secretsmanager_secret" "demo" {
  name = local.secret_name
  tags = merge(var.tags, { "Name" = local.secret_name })
}

resource "aws_secretsmanager_secret_version" "demo" {
  secret_id = aws_secretsmanager_secret.demo.id
  secret_string = jsonencode({
    username = "demo"
    password = "demo123"
  })
}
