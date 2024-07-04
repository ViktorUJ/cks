resource "aws_instance" "master" {
  for_each                    = toset(var.work_pc.node_type == "ondemand" ? ["enable"] : [])
  iam_instance_profile        = aws_iam_instance_profile.server.id
  associate_public_ip_address = "true"
  ami                         = var.work_pc.ami_id != "" ? var.work_pc.ami_id : data.aws_ami.master.image_id
  instance_type               = var.work_pc.instance_type
  subnet_id                   = local.subnets[var.work_pc.subnet_number]
  key_name                    = var.work_pc.key_name != "" ? var.work_pc.key_name : null
  security_groups             = [aws_security_group.servers.id]

  user_data = local.user_data
  tags      = local.tags_all

  root_block_device {
    volume_size           = var.work_pc.root_volume.size
    volume_type           = var.work_pc.root_volume.type
    delete_on_termination = true
    tags                  = local.tags_all
    encrypted             = true
  }

  lifecycle {
    ignore_changes = [
      instance_type,
      user_data,
      root_block_device,
      key_name,
      security_groups
    ]
  }
}

resource "aws_ebs_volume" "master" {
  for_each = var.work_pc.node_type == "ondemand" ? var.work_pc.non_root_volumes : {}

  size              = each.value.size
  type              = each.value.type
  encrypted         = lookup(each.value, "encrypted", false)
  availability_zone = data.aws_subnet.active.availability_zone

  tags = local.tags_all
}

data "aws_subnet" "active" {
  id = local.subnets[var.work_pc.subnet_number]
}

resource "aws_volume_attachment" "master" {
  for_each = var.work_pc.node_type == "ondemand" ? var.work_pc.non_root_volumes : {}

  device_name = each.key
  volume_id   = aws_ebs_volume.master[each.key].id
  instance_id = aws_instance.master["enable"].id
}
