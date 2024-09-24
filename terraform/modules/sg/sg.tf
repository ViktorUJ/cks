resource "aws_security_group" "servers1" {
  name        = "${local.prefix}-mock-${var.app_name}-pc1"
  description = "${local.prefix}-mock-${var.app_name}-pc1"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["8.8.8.8/32"]
    description = "ssh"
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ssh for all "
  }

  ingress {
    from_port   = "9090"
    to_port     = "9090"
    protocol    = "tcp"
    cidr_blocks = ["9.9.9.9/32"]
    description = "prometheus"
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags_all

}

resource "aws_security_group" "servers2" {
  name        = "${local.prefix}-mock-${var.app_name}-pc2"
  description = "${local.prefix}-mock-${var.app_name}-pc2"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["8.8.8.8/32"]
    description = "ssh"
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ssh for all "
  }

  ingress {
    from_port   = "9090"
    to_port     = "9090"
    protocol    = "tcp"
    cidr_blocks = ["9.9.9.9/32"]
    description = "prometheus"
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags_all

}