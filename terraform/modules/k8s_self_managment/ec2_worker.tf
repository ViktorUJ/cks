
resource "aws_launch_template" "worker" {
  for_each      = local.k8s_worker_spot
  name_prefix   = "${local.prefix}-${var.app_name}"
  image_id      = each.value.ami_id != "" ? each.value.ami_id : data.aws_ami.worker["${each.key}"].image_id
  instance_type = each.value.instance_type

  user_data = base64encode(templatefile("template/boot_zip.sh", {
    boot_zip = base64gzip(templatefile(each.value.user_data_template, {
      worker_join         = local.worker_join
      k8s_config          = local.k8s_config
      k8_version          = each.value.k8_version
      runtime             = each.value.runtime
      runtime_script      = file(each.value.runtime_script)
      task_script_url     = each.value.task_script_url
      node_name           = each.key
      node_labels         = each.value.node_labels
      ssh_private_key     = each.value.ssh.private_key
      ssh_pub_key         = each.value.ssh.pub_key
      ssh_password        = random_string.ssh.result
      ssh_password_enable = var.ssh_password_enable
    }))

  }))


  key_name = each.value.key_name != "" ? each.value.key_name : null
  tags     = merge(var.tags_common, local.tags_app, { "Name" = "${local.prefix}-${var.app_name}-worker-${each.key}" })
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.servers.id]
    delete_on_termination       = "true"
    subnet_id                   = local.subnets[each.value.subnet_number]
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      delete_on_termination = "true"
      volume_size           = each.value.root_volume.size
      volume_type           = each.value.root_volume.type
      encrypted             = true

    }

  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags_common, local.tags_app, { "Name" = "${local.prefix}-${var.app_name}-worker-${each.key}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags_common, local.tags_app, { "Name" = "${local.prefix}-${var.app_name}-worker-${each.key}" })
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.server.name
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_spot_fleet_request" "worker" {
  for_each                      = local.k8s_worker_spot
  iam_fleet_role                = aws_iam_role.fleet_role["enable"].arn
  target_capacity               = 1
  wait_for_fulfillment          = true
  terminate_instances_on_delete = true
  launch_template_config {
    launch_template_specification {
      id      = aws_launch_template.worker["${each.key}"].id
      version = aws_launch_template.worker["${each.key}"].latest_version
    }
  }
}


data "aws_instances" "spot_fleet_worker" {
  for_each = local.k8s_worker_spot
  instance_tags = {
    "aws:ec2spot:fleet-request-id" = aws_spot_fleet_request.worker["${each.key}"].id
  }
}
