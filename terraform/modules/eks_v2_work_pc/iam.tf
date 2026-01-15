resource "aws_iam_role" "server" {
  name               = "${local.prefix}-${var.app_name}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = local.tags_all

}

resource "aws_iam_policy" "server" {
  name   = "${local.prefix}-${var.app_name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeAddresses",
                "ec2:DescribeInstances",
                "cloudwatch:PutMetricData",
                "ec2:DescribeTags",
                "ec2:DescribeRegions",
                "ec2:DescribeHosts",
                "cloudwatch:PutMetricStream",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeVpcs",
                "ec2:DescribeVolumes",
                "ec2:DescribeSubnets",
                "ec2:DescribeInstanceStatus",
                "ssm:GetParameter"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${var.s3_k8s_config}/*",
                "arn:aws:s3:::${var.s3_k8s_config}"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}


resource "aws_iam_policy_attachment" "server" {
  name       = "${local.prefix}-${var.app_name}"
  policy_arn = aws_iam_policy.server.arn
  roles      = [aws_iam_role.server.name]
}


resource "aws_iam_instance_profile" "server" {
  name = "${local.prefix}-${var.app_name}"
  role = aws_iam_role.server.name
}


resource "aws_eks_access_entry" "server_admin" {
  cluster_name  = var.name
  principal_arn = aws_iam_role.server.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "server_admin" {
  cluster_name  = var.name
  principal_arn = aws_iam_role.server.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

