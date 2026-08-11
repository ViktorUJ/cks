# --- IRSA role for the Fluent Bit DaemonSet (chapter 34) ---
# Trust policy on the cluster OIDC provider, scoped to the Fluent Bit ServiceAccount
# (system:serviceaccount:<namespace>:<service_account_name>). Defaults match the aws-for-fluent-bit
# Helm chart (aws/eks-charts): namespace amazon-cloudwatch, ServiceAccount aws-for-fluent-bit.
resource "aws_iam_role" "fluentbit_irsa" {
  name = local.role_name

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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.fluent_bit_namespace}:${local.fluent_bit_service_account}"
        }
      }
    }]
  })

  tags = merge(var.tags, { "Name" = local.role_name })
}

# Minimal permissions for the cloudwatch_logs output plugin (section 34.7): create the log
# group and its streams on first write, put log events, describe streams, and set retention
# (section 34.6, задание про retention policy) - scoped to this lab's log group and the log
# streams under it, not to every log group in the account. logs:DescribeLogGroups is the one
# exception: AWS documents this action (and DescribeResourcePolicies/PutResourcePolicy) as
# requiring a `*` resource, it does not support scoping to a single log group ARN.
resource "aws_iam_role_policy" "fluentbit_cloudwatch_logs" {
  name = "${local.role_name}-cloudwatch-logs"
  role = aws_iam_role.fluentbit_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogsWriteAndManage"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy",
        ]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}:log-stream:*",
        ]
      },
      {
        Sid      = "CloudWatchLogsDescribeGroups"
        Effect   = "Allow"
        Action   = ["logs:DescribeLogGroups"]
        Resource = "*"
      }
    ]
  })
}
