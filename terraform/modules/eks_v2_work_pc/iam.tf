data "aws_caller_identity" "current" {}

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

## ВНИМАНИЕ: managed-политика ограничена 6144 символами (пробелы AWS не считает).
## Поэтому все statement с "Resource": "*" и без Condition собраны в ОДИН
## statement AnyResourceForLabs, а read-only Describe свёрнуты в Describe*.
## Добавляя права лабам, дописывайте action в этот statement, а не новый блок,
## иначе CreatePolicy упадёт с LimitExceeded: Cannot exceed quota for PolicySize.
resource "aws_iam_policy" "server" {
  name   = "${local.prefix}-${var.app_name}"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AnyResourceForLabs",
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ecr:*",
                "backup:*",

                "ec2:Describe*",
                "elasticfilesystem:Describe*",
                "elasticloadbalancing:Describe*",
                "ssm:GetParameter",
                "ssm:DescribeInstanceInformation",
                "ssm:GetConnectionStatus",
                "iam:ListRoles",
                "iam:ListAttachedRolePolicies",

                "cloudwatch:PutMetricData",
                "cloudwatch:PutMetricStream",
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricData",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:DescribeAlarms",
                "logs:DescribeLogGroups",
                "logs:PutRetentionPolicy",
                "logs:FilterLogEvents",
                "logs:GetLogEvents",
                "aps:ListWorkspaces",
                "aps:DescribeWorkspace",
                "aps:ListRuleGroupsNamespaces",
                "aps:DescribeRuleGroupsNamespace",

                "secretsmanager:CreateSecret",
                "secretsmanager:PutSecretValue",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:DeleteSecret",
                "secretsmanager:TagResource",
                "secretsmanager:ListSecrets",

                "ec2:AssociateVpcCidrBlock",
                "ec2:DisassociateVpcCidrBlock",
                "ec2:CreateSubnet",
                "ec2:DeleteSubnet",
                "ec2:CreateTags",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:CreateSecurityGroup",
                "ec2:DeleteSecurityGroup",
                "ec2:CreateRoute",
                "ec2:ReplaceRoute",
                "ec2:DeleteRoute",
                "ec2:CreateVpcEndpoint",
                "ec2:DeleteVpcEndpoints",
                "ec2:ModifyVpcEndpoint",

                "ec2:DeleteVolume",
                "ec2:DeleteSnapshot",
                "ec2:DeleteNetworkInterface",
                "elasticfilesystem:DeleteAccessPoint",

                "kms:CreateGrant",
                "kms:DescribeKey",
                "kms:RetireGrant",
                "kms:Decrypt",
                "kms:GenerateDataKey",

                "vpc-lattice:List*",
                "vpc-lattice:Get*",
                "vpc-lattice:DeleteServiceNetwork",
                "vpc-lattice:DeleteServiceNetworkVpcAssociation",
                "s3:ListAllMyBuckets",
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "route53:ListHostedZones*",
                "route53:ListResourceRecordSets"
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
            "Sid": "EcrPullThroughCacheSlrForLabs",
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "pullthroughcache.ecr.amazonaws.com"
                }
            }
        },
        {
            "Sid": "LabDemoBucketsForLabs",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:ListBucketVersions",
                "s3:GetBucketVersioning",
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:DeleteObjectVersion",
                "s3:AbortMultipartUpload"
            ],
            "Resource": [
                "arn:aws:s3:::*-mountpoint-demo",
                "arn:aws:s3:::*-mountpoint-demo/*"
            ]
        },
        {
            "Sid": "TestRoleManagementForLabs",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:GetRole",
                "iam:DeleteRole",
                "iam:PutRolePolicy",
                "iam:GetRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:TagRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:ListAttachedRolePolicies"
            ],
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-test-*"
        },
        {
            "Sid": "AssumeTestRoleForLabs",
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-test-*"
        },
        {
            "Sid": "WorkloadIdentityRoleReadForLabs",
            "Effect": "Allow",
            "Action": "iam:GetRole",
            "Resource": [
                "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-irsa-role",
                "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-pod-identity-role",
                "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-lbc-irsa",
                "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-backup"
            ]
        },
        {
            "Sid": "PassPodIdentityRoleForLabs",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-pod-identity-role",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "pods.eks.amazonaws.com"
                }
            }
        },
        {
            "Sid": "VpcResourceControllerPolicyForLabs",
            "Effect": "Allow",
            "Action": [
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy"
            ],
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-cluster-*",
            "Condition": {
                "ArnEquals": {
                    "iam:PolicyARN": "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
                }
            }
        },
        {
            "Sid": "PassAutoModeNodeRoleForLabs",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-eks-auto-*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "eks.amazonaws.com"
                }
            }
        },
        {
            "Sid": "PassTestRoleForLabs",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-test-*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": [
                        "ec2.amazonaws.com",
                        "pods.eks.amazonaws.com",
                        "backup.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Sid": "TestInstanceProfileManagementForLabs",
            "Effect": "Allow",
            "Action": [
                "iam:CreateInstanceProfile",
                "iam:DeleteInstanceProfile",
                "iam:GetInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:TagInstanceProfile"
            ],
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:instance-profile/*-test-*"
        },
        {
            "Sid": "SelfManagedNodeLaunchDependenciesForLabs",
            "Effect": "Allow",
            "Action": "ec2:RunInstances",
            "Resource": [
                "arn:aws:ec2:*::image/*",
                "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:subnet/*",
                "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:network-interface/*",
                "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:security-group/*",
                "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:key-pair/*"
            ]
        },
        {
            "Sid": "SelfManagedNodeLaunchTaggedForLabs",
            "Effect": "Allow",
            "Action": "ec2:RunInstances",
            "Resource": [
                "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
                "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:volume/*"
            ],
            "Condition": {
                "StringLike": {
                    "aws:RequestTag/Name": "*-test-*"
                }
            }
        },
        {
            "Sid": "SelfManagedNodeTerminateForLabs",
            "Effect": "Allow",
            "Action": "ec2:TerminateInstances",
            "Resource": "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
            "Condition": {
                "StringLike": {
                    "ec2:ResourceTag/Name": "*-test-*"
                }
            }
        },
        {
            "Sid": "PassBackupRoleForLabs",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-backup",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "backup.amazonaws.com"
                }
            }
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

