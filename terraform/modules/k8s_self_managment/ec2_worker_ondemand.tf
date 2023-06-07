resource "aws_instance"  "worker" {
  for_each                    = local.k8s_worker_ondemand
  iam_instance_profile        = aws_iam_instance_profile.server.id
  associate_public_ip_address = "true"
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


