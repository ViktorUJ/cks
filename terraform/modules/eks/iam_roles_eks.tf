data "aws_caller_identity" "audit" {
}

resource "aws_iam_role" "eks_admin" {
  name               = "${var.aws}-${var.prefix}-eks-admin"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.audit.account_id}:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}



resource "aws_iam_policy" "eks_admin" {
  name     = "${var.aws}-${var.prefix}-eks-admin"
  policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*"
            ],
            "Resource": "${aws_eks_cluster.eks-cluster.arn}"
        }
    ]
}
EOF

}



resource "aws_iam_policy_attachment" "eks-admin" {
  name       = "${var.aws}-${var.prefix}-eks-admin"
  policy_arn = aws_iam_policy.eks_admin.arn
  roles      = [aws_iam_role.eks_admin.name]
}
