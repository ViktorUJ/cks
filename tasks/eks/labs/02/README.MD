# Karpenter Workshop

## Table of Contents
- [Setup](#setup)
- [Basic NodePool](#basic-nodepool)
- [Scaling Application](#scaling-application)
- [Limit Resources](#limit-resources)
- [Disruption](#disruption)
- [RightSizing](#rightsizing)
- [Drift](#drift)
- [Multi NodePools](#multi-nodepools)
- [Cost Optimization](#cost-optimization)
- [Scheduling Constraints](#scheduling-constraints)
- [Disruption Control](#disruption-control)
- [Control Pod Density](#control-pod-density)
- [EC2 Node Class](#ec2-node-class)
- [Observability](#observability)
- [Migrating from Cluster Autoscaler](#migrating-from-cluster-autoscaler)
- [Clean Up](#clean-up)
- [Workshop Catalog](#workshop-catalog)

## Setup

### Запуск лабораторной работы

Для запуска данной лабораторной работы выполните следующую команду:

```bash
TASK=02 make run_eks_task
```

### Создаваемые ресурсы

При выполнении команды будет развернута инфраструктура AWS с использованием Terraform/Terragrunt, включающая следующие компоненты:

#### Сетевая инфраструктура (VPC)
- **VPC** с CIDR блоком `10.10.0.0/16` в регионе `eu-central-1`
- **Публичные подсети**:
  - `eks-AZ-1` (10.10.1.0/24) в зоне доступности `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) в зоне доступности `eu-central-1b`
- **Приватные подсети**:
  - `private-subnet-1` (10.10.15.0/24) для EKS узлов в `eu-central-1a`
  - `private-subnet-2` (10.10.16.0/24) для EKS узлов в `eu-central-1b`
  - `rds-subnet-1` (10.10.21.0/24) для RDS в `eu-central-1a`
  - `rds-subnet-2` (10.10.22.0/24) для RDS в `eu-central-1b`
- **NAT Gateway** для обеспечения исходящего интернет-трафика из приватных подсетей

#### EKS Кластер
- **EKS Control Plane** версии `1.34`
- **Fargate профиль** для системных подов
- **Karpenter** версии `1.8.1` для автоматического масштабирования узлов
- **EKS Add-ons** (AWS Load Balancer Controller, EBS CSI Driver и др.)

#### Karpenter конфигурация
- Контроллер Karpenter с ресурсами:
  - CPU: 0.4 cores (requests и limits)
  - Memory: 0.5Gi (requests и limits)
- Поддержка Spot инстансов с широким набором типов экземпляров
- Автоматическое обнаружение подсетей через теги `karpenter.sh/discovery`

#### Дополнительные компоненты
- **SSH ключи** для доступа к узлам
- **Security Groups** с соответствующими правилами
- **IAM роли и политики** для Karpenter и EKS
- **OIDC провайдер** для интеграции с AWS сервисами

### Настройка конфигурации

#### Основной файл конфигурации

Все параметры инфраструктуры определены в файле `tasks/eks/labs/02/env.hcl`. Для изменения конфигурации отредактируйте соответствующие параметры:

**Сетевые настройки:**
```hcl
# Основные сетевые параметры
region = "eu-central-1"                    # AWS регион
vpc_default_cidr = "10.10.0.0/16"         # CIDR блок VPC

# Конфигурация подсетей
subnets = {
  public = {
    "pub1" = {
      name = "eks-AZ-1"
      cidr = "10.10.1.0/24"               # Измените CIDR для публичной подсети
      az   = "eu-central-1a"               # Зона доступности
    }
    # ... дополнительные публичные подсети
  }
  private = {
    "eks1" = {
      name = "private-subnet-1"
      cidr = "10.10.15.0/24"              # Измените CIDR для приватной подсети
      az   = "eu-central-1a"
      type = "eks"
    }
    # ... дополнительные приватные подсети
  }
}
```

**EKS и Karpenter настройки:**
```hcl
k8_version = "1.34.1"                      # Версия Kubernetes
instance_type = "t4g.medium"               # Тип инстанса для системных узлов
instance_type_worker = "t3.medium"         # Тип инстанса для рабочих узлов
node_type = "ondemand"                     # ondemand | spot

# Список типов инстансов для Spot узлов
spot_additional_types = [
  "c8g.xlarge", "t4g.medium", "m6gd.2xlarge",
  # ... добавьте или удалите типы по необходимости
]
```

**Дополнительные параметры:**
```hcl
# Сетевые плагины
cni = {
  type = "calico"                          # calico | cilium
  disable_kube_proxy = "false"
}

# Доступ и безопасность
access_cidrs = ["0.0.0.0/0"]              # CIDR блоки для SSH доступа
ssh_password_enable = "true"               # Включить SSH доступ по паролю

# Хранилище
root_volume = {
  type = "gp3"                             # Тип EBS тома
  size = "10"                              # Размер в GB
}
```

#### Переопределение конфигурации модулей

Для более детальной настройки отдельных компонентов, отредактируйте соответствующие файлы `terragrunt.hcl`:

- **VPC**: `tasks/eks/labs/02/vpc/terragrunt.hcl`
- **EKS Control Plane**: `tasks/eks/labs/02/eks_control_plane/terragrunt.hcl`
- **Karpenter**: `tasks/eks/labs/02/eks_karpenter/terragrunt.hcl`
- **EKS Add-ons**: `tasks/eks/labs/02/eks_addons/terragrunt.hcl`
- **Fargate**: `tasks/eks/labs/02/eks_fargate_system/terragrunt.hcl`

#### Пример переопределения Karpenter параметров

В файле `tasks/eks/labs/02/eks_karpenter/terragrunt.hcl`:

```hcl
inputs = {
  karpenter = {
    version = "1.8.1"                      # Версия Karpenter
    controller_replicas = "1"              # Количество реплик контроллера
    controller_resources_requests_cpu = "0.4"     # CPU запросы
    controller_resources_requests_memory = "0.5Gi" # Memory запросы
    controller_resources_limits_cpu = "0.4"       # CPU лимиты
    controller_resources_limits_memory = "0.5Gi"   # Memory лимиты
  }
}
```

### Предварительные требования

Убедитесь, что у вас настроены:
- AWS CLI с соответствующими правами доступа
- Terraform и Terragrunt
- Переменные окружения `TF_VAR_USER_ID` и `TF_VAR_ENV_ID`

## Basic NodePool
...existing code...

## Scaling Application
...existing code...

## Limit Resources
...existing code...

## Disruption
...existing code...

## RightSizing
...existing code...

## Drift
...existing code...

## Multi NodePools
...existing code...

## Cost Optimization
...existing code...

## Scheduling Constraints
...existing code...

## Disruption Control
...existing code...

## Control Pod Density
...existing code...

## EC2 Node Class
...existing code...

## Observability
...existing code...

## Migrating from Cluster Autoscaler
...existing code...

## Clean Up
...existing code...

## Workshop Catalog
...existing code...
