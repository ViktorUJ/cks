output "node_group_name" {
  value = aws_eks_node_group.healthy.node_group_name
}

output "node_role_arn" {
  value = aws_iam_role.node.arn
}

output "node_role_name" {
  value = aws_iam_role.node.name
}
