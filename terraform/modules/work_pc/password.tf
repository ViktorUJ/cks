resource "random_password" "ssh" {
  length = 10
  special = false
}