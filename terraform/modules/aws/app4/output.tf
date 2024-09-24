output "subnets" {
  value = var.subnets
}

output "sever" {
  value = aws_instance.server.id
}