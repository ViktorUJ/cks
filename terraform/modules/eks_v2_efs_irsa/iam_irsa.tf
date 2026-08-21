locals {
  # OIDC issuer host/path without https://, used in StringEquals keys
  oidc_provider = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")

  efs_csi_namespace       = "kube-system"
  efs_csi_service_account = "efs-csi-controller-sa"
}

# --- IAM Role (IRSA) ---
resource "aws_iam_role" "efs_csi_irsa" {
  name = "${var.name}-efs-csi-irsa"

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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.efs_csi_namespace}:${local.efs_csi_service_account}"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role       = aws_iam_role.efs_csi_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
}
