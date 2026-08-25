# Amazon Managed Service for Prometheus (AMP) workspace. This is the whole component:
# a managed, Prometheus-compatible backend with its own remote-write endpoint and PromQL
# API. There is no server to run and no retention to size - that is the point (chapter 33).
resource "aws_prometheus_workspace" "demo" {
  alias = var.alias
  tags  = merge(var.tags, { "Name" = var.alias })
}
