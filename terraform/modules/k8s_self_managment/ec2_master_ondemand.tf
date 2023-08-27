resource "aws_instance" "master" {
    for_each = toset(var.node_type == "ondemand" ? ["enable"] : [])
  iam_instance_profile = aws_iam_instance_profile.server.id
  associate_public_ip_address = "true"
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
#  user_data = data.template_file.master.rendered
  user_data =templatefile(var.k8s_master.user_data_template , {
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
  })
  tags      = local.tags_all
  root_block_device {
    volume_size           = var.k8s_master.root_volume.size
    volume_type           = var.k8s_master.root_volume.type
    delete_on_termination = true
    tags                  = local.tags_all
    encrypted             = true
  }


}

