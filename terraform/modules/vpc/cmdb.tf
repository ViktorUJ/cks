resource "time_static" "time" {}


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

resource "aws_dynamodb_table_item" "cmdb_update" {
  hash_key = "LockID"
  table_name = data.aws_dynamodb_table.cmdb.name
  item = <<ITEM
{
  "LockID": {"S": "CMDB_${local.prefix}_${var.app_name}"},
  "time_stamp": {"S": "${time_static.time.unix}"},
  "USER_ID": {"S": "${var.USER_ID}"},
  "ENV_ID": {"S": "${var.ENV_ID}"},
  "vpc_id": {"S": "${aws_vpc.default.id}"},
  "subnets_az_cmdb": {"S": "${local.subnets_az_cmdb}"}
    }
ITEM

}
