locals {
  # OIDC issuer host/path without https://, used in StringEquals keys
  oidc_provider = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")

  vpclattice_namespace       = "aws-application-networking-system"
  vpclattice_service_account = "gateway-api-controller"
}

# --- IAM Role (IRSA) for the AWS Gateway API Controller (VPC Lattice) ---
resource "aws_iam_role" "vpclattice_irsa" {
  name = "${var.name}-vpclattice-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.this.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider}:aud" = "sts.amazonaws.com"
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.vpclattice_namespace}:${local.vpclattice_service_account}"
        }
      }
    }]
  })

  tags = var.tags
}

# --- IAM Policy for the controller ---
# ВНИМАНИЕ: это копия recommended-inline-policy.json из репозитория
# aws/aws-application-networking-k8s (files/controller-installation/recommended-inline-policy.json,
# ветка main) на момент написания модуля. Перед использованием в продакшене сверьте документ с
# актуальной версией в репозитории контроллера - политика периодически меняется вместе с новыми
# возможностями контроллера.
resource "aws_iam_policy" "vpclattice" {
  name        = "VPCLatticeControllerIAMPolicy-${var.name}"
  description = "Permissions for the AWS Gateway API Controller (VPC Lattice reconciliation)"

  policy = <<-JSON
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "vpc-lattice:*",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeSecurityGroups",
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:DescribeLogGroups",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "tag:GetResources",
          "firehose:TagDeliveryStream",
          "s3:GetBucketPolicy",
          "s3:PutBucketPolicy",
          "tag:TagResources",
          "tag:UntagResources",
          "acm:ListCertificates"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": "iam:CreateServiceLinkedRole",
        "Resource": "arn:aws:iam::*:role/aws-service-role/vpc-lattice.amazonaws.com/AWSServiceRoleForVpcLattice",
        "Condition": {
          "StringLike": {
            "iam:AWSServiceName": "vpc-lattice.amazonaws.com"
          }
        }
      },
      {
        "Effect": "Allow",
        "Action": "iam:CreateServiceLinkedRole",
        "Resource": "arn:aws:iam::*:role/aws-service-role/delivery.logs.amazonaws.com/AWSServiceRoleForLogDelivery",
        "Condition": {
          "StringLike": {
            "iam:AWSServiceName": "delivery.logs.amazonaws.com"
          }
        }
      }
    ]
  }
  JSON
}

resource "aws_iam_role_policy_attachment" "vpclattice" {
  role       = aws_iam_role.vpclattice_irsa.name
  policy_arn = aws_iam_policy.vpclattice.arn
}
