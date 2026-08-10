locals {
  # OIDC issuer host/path without https://, used in StringEquals keys
  oidc_provider = replace(data.aws_iam_openid_connect_provider.this.url, "https://", "")

  extdns_namespace       = "kube-system"
  extdns_service_account = "external-dns"
}

# --- IAM Role (IRSA) for external-dns ---
resource "aws_iam_role" "extdns_irsa" {
  name = "${var.name}-extdns-irsa"

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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.extdns_namespace}:${local.extdns_service_account}"
        }
      }
    }]
  })

  tags = var.tags
}

# --- IAM Policy for external-dns ---
# Минимальные права по документации external-dns (docs/tutorials/aws.md репозитория
# kubernetes-sigs/external-dns): изменять записи и читать теги в зонах кластера, плюс
# список всех зон, чтобы контроллер мог найти нужную private hosted zone по суффиксу.
resource "aws_iam_policy" "extdns" {
  name        = "AllowExternalDNSUpdates-${var.name}"
  description = "Minimal Route 53 permissions for external-dns (ChangeResourceRecordSets, list zones)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources"
        ]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "extdns" {
  role       = aws_iam_role.extdns_irsa.name
  policy_arn = aws_iam_policy.extdns.arn
}
