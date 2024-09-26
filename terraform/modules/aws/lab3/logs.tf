resource "aws_cloudwatch_log_group" "app_log_group" {
  name              = "/aws/app/${var.prefix}-${var.app_name}"
  retention_in_days = 14  # Настройте по необходимости
}