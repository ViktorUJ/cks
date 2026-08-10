# --- IAM Role (IRSA) for the aws-mountpoint-s3-csi-driver managed addon ---
resource "aws_iam_role" "s3_csi_irsa" {
  name = "${var.name}-s3-csi-irsa"

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
          "${local.oidc_provider}:sub" = "system:serviceaccount:${local.s3_csi_namespace}:${local.s3_csi_service_account}"
        }
      }
    }]
  })

  tags = var.tags
}

# Explicit least-privilege permissions (chapter 25), not the AmazonS3FullAccess managed
# policy: s3:ListBucket on the bucket itself, s3:GetObject/PutObject/AbortMultipartUpload
# on objects inside it.
resource "aws_iam_role_policy" "s3_csi_irsa" {
  name = "${var.name}-s3-csi-irsa-policy"
  role = aws_iam_role.s3_csi_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "MountpointListBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.mountpoint_demo.arn]
      },
      {
        Sid    = "MountpointObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
        ]
        Resource = ["${aws_s3_bucket.mountpoint_demo.arn}/*"]
      }
    ]
  })
}
