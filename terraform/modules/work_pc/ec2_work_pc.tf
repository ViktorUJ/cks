data "template_file" "master" {
  template = file(var.work_pc.user_data_template)
  vars     = {
     clusters_config = var.work_pc.clusters_config
  }
}

resource "aws_spot_instance_request" "master" {
  associate_public_ip_address = "true"
  wait_for_fulfillment        = true
  ami                         = var.work_pc.ami_id
  instance_type               = var.work_pc.instance_type
  subnet_id                   = local.subnets[var.work_pc.subnet_number]
  key_name                    = var.work_pc.key_name
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
  user_data = data.template_file.master.rendered
  tags      = local.tags_all
  root_block_device {
    volume_size           = var.work_pc.root_volume.size
    volume_type           = var.work_pc.root_volume.type
    delete_on_termination = true
    tags                  = local.tags_all
    encrypted             = true
  }

}

resource "aws_eip" "master" {
  vpc  = true
  tags = local.tags_all_k8_master
}

resource "aws_eip_association" "master" {
  instance_id   = aws_spot_instance_request.master.spot_instance_id
  allocation_id = aws_eip.master.id
}

resource "aws_ec2_tag" "master_ec2" {
  for_each    = local.tags_all_k8_master
  resource_id = aws_spot_instance_request.master.spot_instance_id
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "master_ebs" {
  for_each    = local.tags_all_k8_master
  resource_id = aws_spot_instance_request.master.root_block_device[0].volume_id
  key         = each.key
  value       = each.value
}
