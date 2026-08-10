output "role_arn" {
  value = aws_iam_role.extdns_irsa.arn
}

output "role_name" {
  value = aws_iam_role.extdns_irsa.name
}

output "zone_id" {
  value = aws_route53_zone.private.zone_id
}

output "zone_domain" {
  value = aws_route53_zone.private.name
}

output "zone_name_servers" {
  value = aws_route53_zone.private.name_servers
}

output "certificate_arn" {
  value = aws_acm_certificate.selfsigned.arn
}
