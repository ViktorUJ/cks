resource "tls_private_key" "work" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
