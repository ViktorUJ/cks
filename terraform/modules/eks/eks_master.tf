resource "aws_iam_role" "eks-cluster" {
  name = "${var.aws}-${var.prefix}-eks-master"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-cluster-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_iam_role_policy_attachment" "eks-server-policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks-cluster.name
}

resource "aws_security_group" "eks_master" {
  name        = "${var.aws}-${var.prefix}-eks"
  description = "communication with worker nodes "
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = var.eks.allow_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "UDP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "ICMP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "${var.aws}-${var.prefix}-eks"
  }
}



resource "aws_eks_cluster" "eks-cluster" {
  name                      = "${var.aws}-${var.prefix}-eks"
  role_arn                  = aws_iam_role.eks-cluster.arn
  enabled_cluster_log_types = ["api", "audit"]
  version                   = var.eks.version
  vpc_config {
    security_group_ids = [aws_security_group.eks_master.id]
    subnet_ids         = local.subnets
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks-cluster-policy,
    aws_iam_role_policy_attachment.eks-server-policy,
    aws_cloudwatch_log_group.eks
  ]
}


locals {
  kubeconfig = <<KUBECONFIG


apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.eks-cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.eks-cluster.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
      - --region
      - ${var.region}
      - eks
      - get-token
      - --cluster-name
      - ${aws_eks_cluster.eks-cluster.name}
      command: aws
      env: null
      interactiveMode: IfAvailable
      provideClusterInfo: false
      env:
        - name: AWS_PROFILE
          value: "${var.aws}"
KUBECONFIG
}

