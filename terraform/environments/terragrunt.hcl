locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "sre-learning-platform-state-backet"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 5.17.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.0"
    }
  }
}
variable "s3_k8s_config" {
default="${local.backend_bucket}"
}
variable "backend_dynamodb_table" {
default="${local.backend_dynamodb_table}"
}

variable "region_cmdb" {
default="${local.backend_region}"
}

EOF
}

remote_state {
  backend = "s3"
  config = {
    bucket         = local.backend_bucket
    key            = "terragrunt${path_relative_to_include()}/terraform.tfstate"
    region         = local.backend_region
    encrypt        = true
    dynamodb_table = local.backend_dynamodb_table
  }
}

# EKS сериализует изменения кластера: пока идёт одно обновление (например удаление аддона),
# другие операции над кластером отвечают 409 ResourceInUseException "currently has an update
# in progress". На destroy это даёт гонку между удалением аддонов и удалением Fargate-профиля
# или node group. Ошибка транзиентная - через минуту обновление завершается и та же операция
# проходит, поэтому ретраим её автоматически, а не просим перезапускать destroy руками.
retryable_errors = [
  "(?s).*ResourceInUseException.*currently has an update in progress.*",
  "(?s).*ResourceInUseException.*Cannot Delete Fargate Profile.*",
  "(?s).*ResourceInUseException.*because cluster.*is in.*UPDATING.*",
  "(?s).*error waiting for.*EKS.*(update|delete).*",
]
retry_max_attempts       = 5
retry_sleep_interval_sec = 30
inputs = {
  region                 = local.backend_region
  backend_bucket         = local.backend_bucket
  backend_dynamodb_table = local.backend_dynamodb_table
}

