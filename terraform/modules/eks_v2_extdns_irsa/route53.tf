# Приватная hosted zone под тестовый домен лабы. Привязана к VPC лабы, поэтому не
# требует владения реальным публичным доменом и резолвится только внутри этой VPC
# (глава 29: private hosted zone для internal ALB/NLB).
resource "aws_route53_zone" "private" {
  name = var.zone_domain

  vpc {
    vpc_id = var.vpc_id
  }

  tags = var.tags
}
