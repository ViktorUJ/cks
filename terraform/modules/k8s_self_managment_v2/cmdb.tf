data "aws_dynamodb_table" "cmdb" {
  name     = var.backend_dynamodb_table
  provider = aws.cmdb
}

resource "aws_dynamodb_table_item" "cmdb" {
  provider   = aws.cmdb
  hash_key   = "LockID"
  table_name = data.aws_dynamodb_table.cmdb.name
  item       = <<ITEM
{
  "LockID": {"S": "${local.item_id_lock}"},
  "time_stamp": {"S": "${time_static.time.unix}"},
  "USER_ID": {"S": "${local.USER_ID}"},
  "ENV_ID": {"S": "${local.ENV_ID}"},
  "STACK_NAME": {"S": "${var.STACK_NAME}"},
  "STACK_TASK": {"S": "${var.STACK_TASK}"},
  "region": {"S": "${var.region}"}

    }
ITEM

}

resource "aws_dynamodb_table_item" "cmdb_data" {
  provider   = aws.cmdb
  hash_key   = "LockID"
  table_name = data.aws_dynamodb_table.cmdb.name
  item       = <<ITEM
{
  "LockID": {"S": "${local.item_id_data}"},
  "time_stamp": {"S": "${time_static.time.unix}"},
  "USER_ID": {"S": "${local.USER_ID}"},
  "ENV_ID": {"S": "${local.ENV_ID}"},
  "STACK_NAME": {"S": "${var.STACK_NAME}"},
  "STACK_TASK": {"S": "${var.STACK_TASK}"},
  "master_instance_id": {"S": "${local.master_instance_id}"},
  "master_ip": {"S": "${local.master_ip_public}"},
  "worker_node_ids": {"S": "${local.worker_node_ids}"},
  "worker_node_ips_private": {"S": "${local.worker_node_ips_private}"},
  "worker_node_ips_public": {"S": "${local.worker_node_ips_public}"},
  "ssh_password": {"S": "${random_string.ssh.result}"},
  "ssh_login": {"S": "ubuntu"},
  "ec2_key": {"S": "${var.k8s_master.key_name}"},
  "region": {"S": "${var.region}"}
    }
ITEM

}
