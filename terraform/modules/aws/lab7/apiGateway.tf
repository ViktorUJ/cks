# Создаем IAM роль для API Gateway
resource "aws_iam_role" "api_gateway_role" {
  name = "api-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

# Создаем API Gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name = "ecs-api"
}

# Создаем ресурс с динамическим маршрутом {proxy+} для перенаправления всех запросов
resource "aws_api_gateway_resource" "ecs_service" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "{proxy+}"
}

# Создаем метод ANY для всех HTTP запросов
resource "aws_api_gateway_method" "any_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.ecs_service.id
  http_method   = "ANY"
  authorization = "NONE"
}

# Интеграция API Gateway с ALB
resource "aws_api_gateway_integration" "ecs_service_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.ecs_service.id
  http_method             = aws_api_gateway_method.any_method.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.ping_pong_lb.dns_name}"  # ALB DNS имя
}

# Создаем деплой API Gateway
resource "aws_api_gateway_deployment" "ecs_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "prod"

  depends_on = [
    aws_api_gateway_integration.ecs_service_integration,
    aws_api_gateway_method.any_method
  ]
}

# Создаем стадию API Gateway
resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.ecs_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  stage_name    = "prod"
}


# Создаем метод для корневого пути
resource "aws_api_gateway_method" "root_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# Интеграция для корневого пути
resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_rest_api.api_gateway.root_resource_id
  http_method             = aws_api_gateway_method.root_method.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.ping_pong_lb.dns_name}"  # ALB DNS имя
}


# Выводим URL API Gateway
output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.api_gateway.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.api_stage.stage_name}/"
  description = "The URL of the API Gateway"
}


