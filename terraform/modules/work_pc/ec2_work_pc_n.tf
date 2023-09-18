resource "aws_launch_template" "master" {
  for_each    = toset(var.work_pc.node_type == "spot" ? ["enable"] : [])
  name_prefix = "${var.aws}-${var.prefix}-${var.app_name}"
  image_id    = var.work_pc.ami_id
  user_data   = base64encode( templatefile(var.work_pc.user_data_template, {
    clusters_config   = join(" ", [for key, value in var.work_pc.clusters_config : "${key}=${value}"])
    kubectl_version   = var.work_pc.util.kubectl_version
    ssh_private_key   = var.work_pc.ssh.private_key
    ssh_pub_key       = var.work_pc.ssh.pub_key
    exam_time_minutes = var.work_pc.exam_time_minutes
    test_url          = var.work_pc.test_url
    task_script_url   = var.work_pc.task_script_url
  }))
  key_name = var.work_pc.key_name
  tags     = local.tags_all_k8_master

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.servers.id]
    delete_on_termination       = "true"
    subnet_id                   = local.subnets[var.work_pc.subnet_number]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = "true"
      volume_size           = var.work_pc.root_volume.size
      volume_type           = var.work_pc.root_volume.type
      encrypted             = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_spot_fleet_request" "master" {
  iam_fleet_role  = aws_iam_instance_profile.server.id
  # spot_price      = "0.005"
  target_capacity = 1

  launch_template_config {
    launch_template_specification {

      id      = aws_launch_template.master.id
      version = aws_launch_template.master["enable"].latest_version
    }
  }
}