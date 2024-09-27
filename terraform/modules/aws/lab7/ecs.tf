resource "aws_ecs_cluster" "example" {
  name = "ecs-cluster"
}

resource "aws_ecs_task_definition" "ping_pong" {
  family                   = "ping-pong-task"
  container_definitions = jsonencode([
    {
      name      = "ping_pong"
      image     = "viktoruj/ping_pong"
      essential = true
      memory    = 512
      cpu       = 256
      portMappings = [
        {
          containerPort = 8080  # Изменили порт контейнера на 8080
          hostPort      = 8080  # Изменили host порт на 8080
        }
      ]
    }
  ])

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_ecs_service" "ping_pong_service" {
  name            = "ping-pong-service"
  cluster         = aws_ecs_cluster.example.id
  task_definition = aws_ecs_task_definition.ping_pong.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnets  # Заменить на ваши ID подсетей
    security_groups = [aws_security_group.lb_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ping_pong_target_group.arn
    container_name   = "ping_pong"
    container_port   = 8080  # Изменили порт контейнера на 8080
  }

  depends_on = [aws_lb_listener.http]
}

resource "aws_security_group" "lb_sg" {
  name        = "lb-sg"
  description = "Allow http traffic"
  vpc_id      = var.vpc_id  # Заменить на ваш VPC ID

  ingress {
    from_port   = 8080  # Изменили порт на 8080
    to_port     = 8080  # Изменили порт на 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Разрешаем доступ из интернета
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "ping_pong_lb" {
  name               = "ping-pong-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = var.subnets  # Заменить на ваши ID подсетей
}

resource "aws_lb_target_group" "ping_pong_target_group" {
  name     = "ping-pong-target-group"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  target_type = "ip"  # Меняем тип на "ip" для работы с awsvpc и Fargate
}


resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ping_pong_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ping_pong_target_group.arn
  }
}

resource "aws_appautoscaling_target" "ecs_scaling" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.example.name}/${aws_ecs_service.ping_pong_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


output "load_balancer_dns" {
  value = aws_lb.ping_pong_lb.dns_name
}


/*
resource "aws_appautoscaling_policy" "ecs_scaling_policy" {
  name               = "request-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  scaling_target_id  = aws_appautoscaling_target.ecs_scaling.id

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
    }

    target_value = 100.0
  }
}

 */
