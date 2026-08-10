# --- IRSA role for the External Secrets Operator controller ---
# Trust policy on the cluster OIDC provider, scoped to the ESO controller ServiceAccount
# (system:serviceaccount:<namespace>:<service_account_name>, see chapter 16, section 16.5).
resource "aws_iam_role" "eso_irsa" {
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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.eso_namespace}:${local.eso_service_account_name}"
        }
      }
    }]
  })

  tags = merge(var.tags, { "Name" = local.role_name })
}

resource "aws_iam_role_policy" "eso_secret_read" {
  name = "${local.role_name}-secret-read"
  role = aws_iam_role.eso_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid      = "GetSecretValue"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [aws_secretsmanager_secret.demo.arn]
      }
      ],
      var.kms_key_arn == null ? [] : [
        {
          Sid      = "DecryptSecretKmsKey"
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = [var.kms_key_arn]
        }
      ]
    )
  })
}
