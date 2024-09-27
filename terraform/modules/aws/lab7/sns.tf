
# SNS Topic для уведомлений
resource "aws_sns_topic" "error_notifications" {
  name = "${var.prefix}-${var.app_name}-error-notifications"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.error_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email # Укажите email для получения уведомлений
}


/*

# CloudWatch Alarm для 4xx ошибок на ALB
resource "aws_cloudwatch_metric_alarm" "alb_4xx_alarm" {
  alarm_name                = "${var.prefix}-${var.app_name}-alb-4xx-errors"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  threshold                 = 5 # Укажите порог (например, если больше 5 ошибок)
  metric_name               = "HTTPCode_ELB_4XX_Count"
  namespace                 = "AWS/ApplicationELB"
  statistic                 = "Sum"
  period                    = 300
  dimensions = {
    LoadBalancer = aws_lb.app_lb.name
  }

  alarm_description = "Alarm when ALB sees 4xx errors"
  alarm_actions     = [aws_sns_topic.error_notifications.arn]
}

# CloudWatch Alarm для 5xx ошибок на ALB
resource "aws_cloudwatch_metric_alarm" "alb_5xx_alarm" {
  alarm_name                = "${var.prefix}-${var.app_name}-alb-5xx-errors"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 1
  threshold                 = 5 # Укажите порог (например, если больше 5 ошибок)
  metric_name               = "HTTPCode_ELB_5XX_Count"
  namespace                 = "AWS/ApplicationELB"
  statistic                 = "Sum"
  period                    = 300
  dimensions = {
    LoadBalancer = aws_lb.app_lb.name
  }

  alarm_description = "Alarm when ALB sees 5xx errors"
  alarm_actions     = [aws_sns_topic.error_notifications.arn]
}

 */