# Самоподписанный сертификат, импортированный в ACM. Реальная DNS-валидация владения
# публичным доменом в автоматической лабе недостижима (нужен домен во владении читателя),
# поэтому сертификат генерируется прямо в terraform (openssl-эквивалент через провайдер
# tls) и загружается в ACM через aws_acm_certificate с полями private_key и
# certificate_body - это путь "import", а не "request" (глава 27, глава 29: ACM живёт
# на балансировщике, ключ не экспортируется, здесь у нас собственный самоподписанный
# ключ именно для проверки certificate-arn на ALB, без цепочки доверия браузера).
resource "tls_private_key" "cert" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "cert" {
  private_key_pem = tls_private_key.cert.private_key_pem

  subject {
    common_name  = var.cert_common_name
    organization = "eks-course-lab"
  }

  validity_period_hours = 8760 # 1 год, достаточно для жизни лабы

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "selfsigned" {
  private_key      = tls_private_key.cert.private_key_pem
  certificate_body = tls_self_signed_cert.cert.cert_pem

  tags = merge(var.tags, { "Name" = "${var.prefix}-selfsigned" })

  lifecycle {
    create_before_destroy = true
  }
}
