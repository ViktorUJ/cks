resource "time_static" "time" {}


data "aws_dynamodb_table" "cmdb" {
  name = var.backend_dynamodb_table

}

resource "aws_dynamodb_table_item" "cmdb" {
  hash_key = "LockID"
  table_name = data.aws_dynamodb_table.cmdb.name
  item = <<ITEM
{
  "LockID": {"S": "${local.item_id_lock}"},
  "time_stamp": {"S": "${time_static.time.unix}"},
  "USER_ID": {"S": "${var.USER_ID}"},
  "ENV_ID": {"S": "${var.ENV_ID}"},
  "region": {"S": "${var.region}"}

    }
ITEM

}

resource "aws_dynamodb_table_item" "cmdb_data" {
  hash_key = "LockID"
  table_name = data.aws_dynamodb_table.cmdb.name
  item = <<ITEM
{
  "LockID": {"S": "${local.item_id_data}"},
  "time_stamp": {"S": "${time_static.time.unix}"},
  "USER_ID": {"S": "${var.USER_ID}"},
  "ENV_ID": {"S": "${var.ENV_ID}"},
  "eks_cluster_name": {"S": "${aws_eks_cluster.eks-cluster.name}"},
  "region": {"S": "${var.region}"}
    }
ITEM

}
