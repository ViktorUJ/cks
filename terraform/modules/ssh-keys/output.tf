output "private_key" {
  value     = tls_private_key.work.private_key_pem
  sensitive = true
}

output "pub_key" {
  value     = tls_private_key.work.public_key_openssh
  sensitive = true
}