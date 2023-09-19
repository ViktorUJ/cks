resource "aws_iam_role" "fleet_role" {
  for_each      = toset(var.work_pc.node_type == "spot" ? ["enable"] : [])
  name = "${var.aws}-${var.prefix}-${var.app_name}-spot-fleet-worker"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "spotfleet.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "fleet_role" {
  for_each      = toset(var.work_pc.node_type == "spot" ? ["enable"] : [])
  name     = "${var.aws}-${var.prefix}-${var.app_name}-work-pc-spot-fleet"
  policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeImages",
                "ec2:DescribeSubnets",
                "ec2:RequestSpotInstances",
                "ec2:TerminateInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:CreateTags",
                "ec2:RunInstances"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": [
                        "ec2.amazonaws.com",
                        "ec2.amazonaws.com.cn"
                    ]
                }
            },
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterInstancesWithLoadBalancer"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:RegisterTargets"
            ],
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:*/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "fleet_role" {
  for_each      = toset(var.work_pc.node_type == "spot" ? ["enable"] : [])
  name       = "${var.aws}-${var.prefix}-${var.app_name}-work-pc-spot-fleet"
  policy_arn = aws_iam_policy.fleet_role["enable"].arn
  roles      = [aws_iam_role.fleet_role["enable"].name]
}


resource "aws_launch_template" "master" {
  for_each      = toset(var.work_pc.node_type == "spot" ? ["enable"] : [])
  name_prefix   = "${var.aws}-${var.prefix}-${var.app_name}"
  image_id      = var.work_pc.ami_id
  instance_type = var.work_pc.instance_type
  user_data     = base64encode( templatefile(var.work_pc.user_data_template, {
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
  tag_specifications {
    resource_type = "instance"
    tags          = local.tags_all_k8_master
  }

   tag_specifications {
    resource_type = "volume"
    tags          = local.tags_all_k8_master
  }

 iam_instance_profile {
    name = aws_iam_instance_profile.server.name
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_spot_fleet_request" "master" {
  depends_on = [
  aws_iam_instance_profile.server,
  aws_security_group.servers,
  ]
  for_each      = toset(var.work_pc.node_type == "spot" ? ["enable"] : [])
  iam_fleet_role       = aws_iam_role.fleet_role["enable"].arn
  target_capacity      = 1
  wait_for_fulfillment = true

  launch_template_config {
    launch_template_specification {

      id      = aws_launch_template.master["enable"].id
      version = aws_launch_template.master["enable"].latest_version
    }
  }
}


data "aws_instances" "spot_fleet" {
  for_each      = toset(var.work_pc.node_type == "spot" ? ["enable"] : [])
  instance_tags = {
    "aws:ec2spot:fleet-request-id" =  aws_spot_fleet_request.master["enable"].id
  }
}
