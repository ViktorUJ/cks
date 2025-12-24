module "fargate_profile" {
  source     = "terraform-aws-modules/eks/aws//modules/fargate-profile"
  version    = "21.10.1"
  depends_on = [aws_dynamodb_table_item.cmdb_data]

  name         = var.fargate.name
  cluster_name = var.name
  subnet_ids   = var.fargate.subnet_ids
  selectors    = var.fargate.subnet_ids
  tags         = var.fargate.tags
}
