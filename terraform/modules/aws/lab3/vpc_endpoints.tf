# Создание VPC endpoint для SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        =var.subnets_private

  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  private_dns_enabled = true
}

# Создание VPC endpoint для SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnets_private

  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  private_dns_enabled = true
}

# Создание VPC endpoint для EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = var.subnets_private

  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  private_dns_enabled = true
}

# Создание Security Group для VPC Endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "${var.prefix}-${var.app_name}-vpc-endpoint-sg"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_default_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
