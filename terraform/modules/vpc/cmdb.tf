resource "time_static" "time" {}


data "aws_dynamodb_table" "cmdb" {
  name = var.backend_dynamodb_table

}

resource "aws_dynamodb_table_item" "cmdb" {
  hash_key = "LockID"
  table_name = data.aws_dynamodb_table.cmdb.name
  item = <<ITEM
{
  "LockID": {"S": "CMDB_${local.prefix}_lock_${var.app_name}"},
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
  "LockID": {"S": "CMDB_${local.prefix}_data_${var.app_name}"},
  "time_stamp": {"S": "${time_static.time.unix}"},
  "USER_ID": {"S": "${var.USER_ID}"},
  "ENV_ID": {"S": "${var.ENV_ID}"},
  "vpc_id": {"S": "${aws_vpc.default.id}"},
  "subnets_az_cmdb": {"S": "${local.subnets_az_cmdb}"},
  "region": {"S": "${var.region}"}
    }
ITEM

}
