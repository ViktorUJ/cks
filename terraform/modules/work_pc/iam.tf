resource "aws_iam_role" "server" {
  name               = "${var.aws}-${var.prefix}-${var.app_name}"
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
  name   = "${var.aws}-${var.prefix}-${var.app_name}"
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
                "ec2:DescribeInstanceStatus"
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
        }
    ]
}
EOF
}

resource "aws_iam_policy" "server-eks" {
  for_each = toset(var.eks_cluster_name== "" ? [] : ["enable"])
  name   = "${var.aws}-${var.prefix}-${var.app_name}-eks"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "eks:DescribeAddonConfiguration",
                "eks:ListClusters",
                "eks:DescribeAddonVersions",
                "eks:RegisterCluster",
                "eks:CreateCluster"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "eks:*",
            "Resource": "arn:aws:eks:*:*:cluster/${var.eks_cluster_name}"
        }
    ]
}
EOF
}


resource "aws_iam_policy_attachment" "server" {
  name       = "${var.aws}-${var.prefix}-${var.app_name}"
  policy_arn = aws_iam_policy.server.arn
  roles      = [aws_iam_role.server.name]
}

resource "aws_iam_policy_attachment" "server-eks" {
  for_each = toset(var.eks_cluster_name== "" ? [] : ["enable"])
  name       = "${var.aws}-${var.prefix}-${var.app_name}-eks"
  policy_arn = aws_iam_policy.server-eks.arn
  roles      = [aws_iam_role.server.name]
}


resource "aws_iam_instance_profile" "server" {
  name = "${var.aws}-${var.prefix}-${var.app_name}"
  role = aws_iam_role.server.name
}