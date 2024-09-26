# Создание WebACL для WAF
resource "aws_wafv2_web_acl" "alb_waf" {
  name        = "${var.prefix}-${var.app_name}-web-acl"
  description = "WAF ACL for ALB"
  scope       = "REGIONAL" # Для ALB используем региональный WAF
  default_action {
    allow {}
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.prefix}-${var.app_name}-waf-metric"
    sampled_requests_enabled   = true
  }

  # Правила WAF
  rule {
    name     = "BlockBadIPs"
    priority = 1
    action {
      block {}
    }
    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.bad_ips.arn
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BadIPsRule"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2
    action {
      block {}
    }
    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
  }

  tags = merge(
    var.tags_common,
    {
      Name = "${var.prefix}-${var.app_name}-web-acl"
    }
  )
}

# Создание IP set для блокировки плохих IP
resource "aws_wafv2_ip_set" "bad_ips" {
  name        = "${var.prefix}-${var.app_name}-bad-ips"
  description = "List of bad IP addresses"
  scope       = "REGIONAL" # Для ALB используем региональный WAF
  ip_address_version = "IPV4"
  addresses = [
    "192.0.2.0/24",  # Пример плохого IP-адреса
  ]
  tags = merge(
    var.tags_common,
    {
      Name = "${var.prefix}-${var.app_name}-bad-ips"
    }
  )
}

# Связывание WAF с ALB
resource "aws_wafv2_web_acl_association" "alb_waf_association" {
  resource_arn = aws_lb.app_lb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}

