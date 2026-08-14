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
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSecurityGroupRules",
                "elasticfilesystem:DescribeFileSystems",
                "elasticfilesystem:DescribeMountTargets",
                "elasticfilesystem:DescribeMountTargetSecurityGroups",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetHealth",
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
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:CreateSecret",
                "secretsmanager:PutSecretValue",
                "secretsmanager:GetSecretValue",
                "secretsmanager:DescribeSecret",
                "secretsmanager:DeleteSecret",
                "secretsmanager:TagResource",
                "secretsmanager:ListSecrets"
            ],
            "Resource": "*"
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
                "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-lbc-irsa"
            ]
        },
        {
            "Sid": "ListRolesForLabs",
            "Effect": "Allow",
            "Action": "iam:ListRoles",
            "Resource": "*"
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
            "Sid": "PassTestRoleToEc2ForLabs",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-test-*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "ec2.amazonaws.com"
                }
            }
        },
        {
            "Sid": "PassTestRoleForPodIdentityForLabs",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-test-*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "pods.eks.amazonaws.com"
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
            "Sid": "SelfManagedNodeTagOnLaunchForLabs",
            "Effect": "Allow",
            "Action": "ec2:CreateTags",
            "Resource": "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:*/*",
            "Condition": {
                "StringEquals": {
                    "ec2:CreateAction": "RunInstances"
                }
            }
        },
        {
            "Sid": "VpcCidrAndSubnetPlanningForLabs",
            "Effect": "Allow",
            "Action": [
                "ec2:AssociateVpcCidrBlock",
                "ec2:DisassociateVpcCidrBlock",
                "ec2:CreateSubnet",
                "ec2:DeleteSubnet",
                "ec2:CreateTags",
                "ec2:DescribeInstanceTypes",
                "eks:UpdateAddon",
                "eks:DescribeAddon",
                "eks:DescribeUpdate"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudWatchLogsReadForLoggingLabs",
            "Effect": "Allow",
            "Action": [
                "logs:DescribeLogGroups",
                "logs:PutRetentionPolicy",
                "logs:FilterLogEvents",
                "logs:GetLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ObservabilityReadForMetricsLabs",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricData",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:DescribeAlarms",
                "aps:ListWorkspaces",
                "aps:DescribeWorkspace",
                "aps:ListRuleGroupsNamespaces",
                "aps:DescribeRuleGroupsNamespace"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SecurityGroupTroubleshootingForLabs",
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSecurityGroupRules"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AwsBackupForLabs",
            "Effect": "Allow",
            "Action": "backup:*",
            "Resource": "*"
        },
        {
            "Sid": "PassTestRoleForBackupForLabs",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-test-*",
            "Condition": {
                "StringEquals": {
                    "iam:PassedToService": "backup.amazonaws.com"
                }
            }
        },
        {
            "Sid": "KmsForAwsBackupVaultLabs",
            "Effect": "Allow",
            "Action": [
                "kms:CreateGrant",
                "kms:DescribeKey",
                "kms:RetireGrant",
                "kms:Decrypt",
                "kms:GenerateDataKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "TrafficAndEndpointsForLabs",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateRoute",
                "ec2:ReplaceRoute",
                "ec2:DeleteRoute",
                "ec2:CreateVpcEndpoint",
                "ec2:DeleteVpcEndpoints",
                "ec2:ModifyVpcEndpoint",
                "ec2:DescribeVpcEndpoints",
                "ec2:DescribeNatGateways",
                "ec2:DescribeRouteTables",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VpcLatticeReadForLabs",
            "Effect": "Allow",
            "Action": [
                "vpc-lattice:List*",
                "vpc-lattice:Get*",
                "ec2:DescribeManagedPrefixLists"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AcmRoute53ReadForIngressLabs",
            "Effect": "Allow",
            "Action": [
                "acm:ListCertificates",
                "acm:DescribeCertificate",
                "route53:ListHostedZones*",
                "route53:ListResourceRecordSets"
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

