resource "random_string" "ssh" {
  for_each = var.ssh_password_enable ? toset(["enabled"]) : toset([])

  length  = 10
  special = false
}
