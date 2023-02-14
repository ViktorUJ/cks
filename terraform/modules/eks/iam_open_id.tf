
data "tls_certificate" "cluster" {
  url = join("", aws_eks_cluster.eks-cluster.*.identity.0.oidc.0.issuer)
}

resource "aws_iam_openid_connect_provider" "default" {
  url             = join("", aws_eks_cluster.eks-cluster.*.identity.0.oidc.0.issuer)
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [join("", data.tls_certificate.cluster.*.certificates.0.sha1_fingerprint)]
}



resource "aws_iam_role" "eks-app-WebIdentity" {
  name = "${var.aws}-${var.prefix}-eks-WebIdentity"

  assume_role_policy = <<POLICY
{
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {
                        "Federated": "${aws_iam_openid_connect_provider.default.arn}"
                    },
                    "Action": "sts:AssumeRoleWithWebIdentity",
                    "Condition": {
                        "StringEquals": {
                            "${aws_iam_openid_connect_provider.default.url}:aud": "sts.amazonaws.com"
                        }
                    }
                }
            ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-iam-app" {
  policy_arn = aws_iam_policy.s3.arn
  role       = aws_iam_role.eks-app-WebIdentity.name
}