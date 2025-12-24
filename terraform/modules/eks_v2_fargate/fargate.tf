module "fargate_profile" {
  for_each   = var.fargate
  source     = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version    = "21.10.1"
  depends_on = [aws_dynamodb_table_item.cmdb_data]

  name         = each.key
  cluster_name = var.name
  subnet_ids   = each.value.subnet_ids
  selectors    = each.value.selectors
  tags         = each.value.tags
}
