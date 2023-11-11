resource "aws_security_group" "servers" {
  name        = "${var.aws}-${var.prefix}-k8-self-managment"
  description = "${var.aws}-${var.prefix}-k8-self-managment"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = var.k8s_master.cidrs
    description = "ssh"
  }
  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = var.k8s_master.cidrs
    description = "http"
  }

  ingress {
    from_port   = "443"
    to_port     = "443"
    protocol    = "tcp"
    cidr_blocks = var.k8s_master.cidrs
    description = "https"
  }


  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags_all

}
