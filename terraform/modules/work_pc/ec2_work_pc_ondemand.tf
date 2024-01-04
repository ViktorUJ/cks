resource "aws_instance" "master" {
  for_each                    = toset(var.work_pc.node_type == "ondemand" ? ["enable"] : [])
  iam_instance_profile        = aws_iam_instance_profile.server.id
  associate_public_ip_address = "true"
  ami                         = var.work_pc.ami_id != "" ? var.work_pc.ami_id : data.aws_ami.master.image_id
  instance_type               = var.work_pc.instance_type
  subnet_id                   = local.subnets[var.work_pc.subnet_number]
  key_name                    = var.work_pc.key_name != "" ? var.work_pc.key_name : null
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
  user_data = templatefile(var.work_pc.user_data_template, {
    clusters_config   = join(" ", [for key, value in var.work_pc.clusters_config : "${key}=${value}"])
    kubectl_version   = var.work_pc.util.kubectl_version
    ssh_private_key   = var.work_pc.ssh.private_key
    ssh_pub_key       = var.work_pc.ssh.pub_key
    exam_time_minutes = var.work_pc.exam_time_minutes
    test_url          = var.work_pc.test_url
    task_script_url   = var.work_pc.task_script_url
    ssh_password      = random_string.ssh.result
    hosts             = local.hosts
  })
  tags = local.tags_all
  root_block_device {
    volume_size           = var.work_pc.root_volume.size
    volume_type           = var.work_pc.root_volume.type
    delete_on_termination = true
    tags                  = local.tags_all
    encrypted             = true
  }
}

resource "aws_ebs_volume" "master" {
  for_each = var.work_pc.node_type == "ondemand" ? var.work_pc.non_root_volumes : {}

  size              = each.value.size
  type              = each.value.type
  encrypted         = lookup(each.value, "encrypted", false)
  availability_zone = data.aws_subnet.active.availability_zone

  tags = local.tags_all_k8_master
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
