# --- IRSA role: trust policy on the cluster OIDC provider, scoped to one ServiceAccount ---
# The `sub` condition below is the exact string a correct pod must match:
# system:serviceaccount:<irsa.namespace>:<irsa.service_account_name>. The lab (chapter 47)
# reproduces AccessDenied by pointing the SA annotation at this role from a DIFFERENT
# namespace, so the trust policy `sub` check fails during sts:AssumeRoleWithWebIdentity.
resource "aws_iam_role" "irsa" {
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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${var.irsa.namespace}:${var.irsa.service_account_name}"
        }
      }
    }]
  })

  tags = merge(var.tags, { "Name" = local.role_name })
}

resource "aws_iam_role_policy" "irsa_s3_read" {
  name = "${local.role_name}-s3-read"
  role = aws_iam_role.irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.demo.arn]
      },
      {
        Sid      = "GetObject"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${aws_s3_bucket.demo.arn}/*"]
      }
    ]
  })
}
