# Secrets Manager secret used by the Pod Identity demo pod. Name is predictable (prefix +
# app_name), so the worker can find it by name without reading terraform output.
resource "aws_secretsmanager_secret" "demo" {
  name = local.secret_name
  tags = merge(var.tags, { "Name" = local.secret_name })
  # Имя секрета предсказуемое (prefix + app_name), лаба может быть удалена и развёрнута
  # заново с тем же именем. По умолчанию AWS держит удалённый секрет в recovery window
  # 7-30 дней ("scheduled for deletion"), и повторное create-secret с тем же именем
  # падает с InvalidRequestException. recovery_window_in_days = 0 удаляет секрет сразу,
  # без периода восстановления - для учебного стенда это уместно.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "demo" {
  secret_id = aws_secretsmanager_secret.demo.id
  secret_string = jsonencode({
    username = "demo"
    password = "demo123"
  })
}
