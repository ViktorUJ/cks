data "template_file" "worker" {
  for_each = var.k8s_worker
  template = file(each.value.user_data_template)
  vars     = {
    worker_join     = local.worker_join
    k8s_config      = local.k8s_config
    k8_version      = each.value.k8_version
    runtime         = each.value.runtime
    runtime_script  = file(each.value.runtime_script)
    task_script_url = each.value.task_script_url
    node_name       = each.key
    node_labels     = each.value.node_labels
    ssh_private_key = each.value.ssh.private_key
    ssh_pub_key     = each.value.ssh.pub_key
  }
}

resource "aws_spot_instance_request" "worker" {
  for_each                    = var.k8s_worker
  iam_instance_profile        = aws_iam_instance_profile.server.id
  associate_public_ip_address = "true"
  wait_for_fulfillment        = true
  ami                         = each.value.ami_id
  instance_type               = each.value.instance_type
  subnet_id                   = local.subnets[each.value.subnet_number]
  key_name                    = each.value.key_name
  security_groups             = [aws_security_group.servers.id]
  lifecycle {
    ignore_changes = [
      instance_type,
      user_data,
      root_block_device,
      key_name,
      security_groups
    ]
  }
  user_data = data.template_file.worker["${each.key}"].rendered
  tags      = local.tags_all
  root_block_device {
    volume_size           = each.value.root_volume.size
    volume_type           = each.value.root_volume.type
    delete_on_termination = true
    tags                  = local.tags_all
    encrypted             = true
  }

}


resource "aws_ec2_tag" "worker_ec2" {
  for_each    = var.k8s_worker
  resource_id = aws_spot_instance_request.worker["${each.key}"].spot_instance_id
  key         = "Name"
  value       = "${var.aws}-${var.prefix}-${var.app_name}-worker-${each.key}"
}

resource "aws_ec2_tag" "worker_ebs" {
  for_each    = var.k8s_worker
  resource_id = aws_spot_instance_request.worker["${each.key}"].root_block_device[0].volume_id
  key         = "Name"
  value       = "${var.aws}-${var.prefix}-${var.app_name}-worker-${each.key}"
}
