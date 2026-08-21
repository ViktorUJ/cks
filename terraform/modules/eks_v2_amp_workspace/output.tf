output "workspace_id" {
  value = aws_prometheus_workspace.demo.id
}

output "workspace_arn" {
  value = aws_prometheus_workspace.demo.arn
}

output "prometheus_endpoint" {
  value = aws_prometheus_workspace.demo.prometheus_endpoint
}
