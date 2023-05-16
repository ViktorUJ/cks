data "template_file" "master" {
  template = file(var.work_pc.user_data_template)
  vars     = {
    clusters_config   = join(" ", [for key, value in var.work_pc.clusters_config : "${key}=${value}"])
    kubectl_version   = var.work_pc.util.kubectl_version
    ssh_private_key   = var.work_pc.ssh.private_key
    ssh_pub_key       = var.work_pc.ssh.pub_key
    exam_time_minutes = var.work_pc.exam_time_minutes
    test_url          = var.work_pc.test_url
  }
}

resource "aws_spot_instance_request" "master" {
  iam_instance_profile        = aws_iam_instance_profile.server.id
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

resource "time_sleep" "wait_master" {
  depends_on = [aws_spot_instance_request.master]

  create_duration = "10s"
}


resource "aws_ec2_tag" "master_ec2" {
  depends_on = [time_sleep.wait_master]
  for_each    = local.tags_all_k8_master
  resource_id = aws_spot_instance_request.master.spot_instance_id
  key         = each.key
  value       = each.value
}

resource "aws_ec2_tag" "master_ebs" {
  depends_on = [time_sleep.wait_master]
  for_each    = local.tags_all_k8_master
  resource_id = aws_spot_instance_request.master.root_block_device[0].volume_id
  key         = each.key
  value       = each.value
}
