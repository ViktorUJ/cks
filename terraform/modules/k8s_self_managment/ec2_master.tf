data "template_file" "master" {
  template = file(var.k8s_master.user_data_template)
  vars     = {
    worker_join      = local.worker_join
    k8s_config       = local.k8s_config
    external_ip      = local.external_ip
    k8_version       = var.k8s_master.k8_version
    runtime          = var.k8s_master.runtime
    utils_enable     = var.k8s_master.utils_enable
    pod_network_cidr = var.k8s_master.pod_network_cidr
    runtime_script   = file(var.k8s_master.runtime_script)
    task_script_url  = var.k8s_master.task_script_url
    calico_url       = var.k8s_master.calico_url
    ssh_private_key  = var.k8s_master.ssh.private_key
    ssh_pub_key      = var.k8s_master.ssh.pub_key
  }
}

resource "aws_spot_instance_request" "master" {
  iam_instance_profile        = aws_iam_instance_profile.server.id
  associate_public_ip_address = "true"
  wait_for_fulfillment        = true
  ami                         = var.k8s_master.ami_id
  instance_type               = var.k8s_master.instance_type
  subnet_id                   = local.subnets[var.k8s_master.subnet_number]
  key_name                    = var.k8s_master.key_name
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
    volume_size           = var.k8s_master.root_volume.size
    volume_type           = var.k8s_master.root_volume.type
    delete_on_termination = true
    tags                  = local.tags_all
    encrypted             = true
  }

}

resource "aws_eip" "master" {
  for_each = toset(var.k8s_master.eip == "true" ? ["enable"] : [])
  vpc  = true
  tags = local.tags_all_k8_master
}

resource "aws_eip_association" "master" {
  for_each = toset(var.k8s_master.eip == "true" ? ["enable"] : [])
  instance_id   = aws_spot_instance_request.master.spot_instance_id
  allocation_id = aws_eip.master["enable"].id
}

resource "time_sleep" "wait_master" {
  depends_on = [aws_spot_instance_request.master]

  create_duration = "15s"
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
