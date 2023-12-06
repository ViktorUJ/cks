data "aws_dynamodb_table" "cmdb" {
  name = var.backend_dynamodb_table

}

resource "aws_dynamodb_table_item" "cmdb" {
  hash_key = "LockID"
  table_name = data.aws_dynamodb_table.cmdb.name
  item = <<ITEM
{
  "LockID": {"S": "CMDB_${local.prefix}_${var.app_name}"}

    }
ITEM

}