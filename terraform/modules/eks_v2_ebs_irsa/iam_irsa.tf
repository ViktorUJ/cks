locals {
  # OIDC issuer host/path without https://, used in StringEquals keys
  oidc_provider = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")

  ebs_csi_namespace       = "kube-system"
  ebs_csi_service_account = "ebs-csi-controller-sa"
}

# --- IAM Role (IRSA) ---
resource "aws_iam_role" "ebs_csi_irsa" {
  name = "${var.name}-ebs-csi-irsa"

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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.ebs_csi_namespace}:${local.ebs_csi_service_account}"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}