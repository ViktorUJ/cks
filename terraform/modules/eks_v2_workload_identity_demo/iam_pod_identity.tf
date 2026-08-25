# --- Pod Identity role: trust policy on the pods.eks.amazonaws.com service principal ---
# Not tied to any cluster OIDC provider. The link to a namespace/ServiceAccount is created
# later via `aws eks create-pod-identity-association`, not by terraform in this module.
resource "aws_iam_role" "pod_identity" {
  name = local.pod_identity_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEksAuthToAssumeRoleForPodIdentity"
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })

  tags = merge(var.tags, { "Name" = local.pod_identity_role_name })
}

resource "aws_iam_role_policy" "pod_identity_secrets_read" {
  name = "${local.pod_identity_role_name}-secrets-read"
  role = aws_iam_role.pod_identity.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "GetSecretValue"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_secretsmanager_secret.demo.arn]
    }]
  })
}
