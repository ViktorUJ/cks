output "subnets" {
  value = var.subnets
}

output "sever" {
  value = aws_instance.server.id
}

output "sever-private" {
  value = aws_instance.server-private.id
}
