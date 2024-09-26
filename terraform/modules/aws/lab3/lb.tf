# Создание ALB
resource "aws_lb" "app_lb" {
  name               = "${var.prefix}-${var.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = var.subnets

  enable_deletion_protection = false
  idle_timeout              = 60

  tags = merge(
    var.tags_common,
    {
      Name = "${var.prefix}-${var.app_name}-alb"
    }
  )
}

# Создание целевой группы для ALB
resource "aws_lb_target_group" "app_target_group" {
  name     = "${var.prefix}-${var.app_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags_common,
    {
      Name = "${var.prefix}-${var.app_name}-tg"
    }
  )
}

# Настройка HTTP-листенера для ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_target_group.arn
  }
}

# Привязка Auto Scaling Group к целевой группе
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.ec2_asg.name
  lb_target_group_arn   = aws_lb_target_group.app_target_group.arn
}

# Security Group для ALB (публичный доступ на порт 80)
resource "aws_security_group" "lb_sg" {
  name        = "${var.prefix}-${var.app_name}-alb-sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Открываем доступ для всех
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags_common,
    {
      Name = "${var.prefix}-${var.app_name}-alb-sg"
    }
  )
}

