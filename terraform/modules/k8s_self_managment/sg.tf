resource "aws_security_group" "servers" {
  name        = "${local.prefix}-k8-self-managment"
  description = "${local.prefix}-k8-self-managment"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = var.k8s_master.cidrs
    description = "ssh"
  }

  ingress {
    from_port   = "30000"
    to_port     = "32767"
    protocol    = "tcp"
    cidr_blocks = var.k8s_master.cidrs
    description = "NodePort k8s"
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    cidr_blocks = var.k8s_master.cidrs
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags_all

}
