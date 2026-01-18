[Английская версия](README.MD)


# Лабораторная работа: Основы Karpenter

## Описание

Эта лабораторная работа познакомит вас с **Karpenter** — инструментом автоматического масштабирования узлов (нод) в кластере Amazon EKS. Karpenter динамически создаёт и удаляет EC2-инстансы в зависимости от потребностей ваших приложений, оптимизируя затраты и производительность.

**Что вы изучите:**
- Как настроить базовый NodePool и EC2NodeClass
- Как Karpenter автоматически масштабирует узлы при изменении нагрузки
- Как управлять ресурсами через лимиты
- Как работает консолидация и оптимизация размеров узлов
- Как обновлять узлы при изменении конфигурации (drift)
- Как использовать несколько NodePool для разных типов нагрузки

## Содержание
- [Подготовка окружения](#подготовка-окружения)
  - [Запуск лабораторной работы](#запуск-лабораторной-работы)
  - [Создаваемые ресурсы](#создаваемые-ресурсы)
  - [Предварительные требования](#предварительные-требования)
- [Базовая настройка NodePool](#базовая-настройка-nodepool)
  - [Проверка работы Karpenter](#проверка-работы-karpenter)
  - [Создание тестового приложения](#создание-тестового-приложения)
  - [Создание NodePool и EC2NodeClass](#создание-nodepool-и-ec2nodeclass)
  - [Проверка автоматического создания узлов](#проверка-автоматического-создания-узлов)
- [Масштабирование приложений](#масштабирование-приложений)
  - [Горизонтальное масштабирование](#горизонтальное-масштабирование)
  - [Автоматическое добавление узлов](#автоматическое-добавление-узлов)
- [Ограничение ресурсов](#ограничение-ресурсов)
  - [Настройка лимитов CPU](#настройка-лимитов-cpu)
  - [Диагностика проблем с лимитами](#диагностика-проблем-с-лимитами)
- [Управление жизненным циклом узлов (Disruption)](#управление-жизненным-циклом-узлов-disruption)
- [Оптимизация размеров узлов (RightSizing)](#оптимизация-размеров-узлов-rightsizing)
  - [Автоматический подбор оптимального размера](#автоматический-подбор-оптимального-размера)
  - [Замена узлов при изменении требований](#замена-узлов-при-изменении-требований)
- [Обновление конфигурации узлов (Drift)](#обновление-конфигурации-узлов-drift)
  - [Обновление AMI образов](#обновление-ami-образов)
  - [Автоматическая миграция на новые версии](#автоматическая-миграция-на-новые-версии)
- [Работа с несколькими NodePool](#работа-с-несколькими-nodepool)
  - [Изоляция нагрузки через Taints и Tolerations](#изоляция-нагрузки-через-taints-и-tolerations)
  - [Специализированные узлы для Job](#специализированные-узлы-для-job)
- [Очистка ресурсов](#очистка-ресурсов)


## Подготовка окружения

### Запуск лабораторной работы
[запуск через docker ](https://github.com/ViktorUJ/cks/blob/AG-122/docs%2Frun_from_docker.MD)
Для запуска лабораторной работы выполните следующую команду:

```bash
TASK=02 make run_eks_task
```

**Что происходит при выполнении команды:**
- Terraform/Terragrunt автоматически развернёт всю необходимую инфраструктуру в AWS
- Процесс займёт примерно 15-20 минут
- В выводе команды вы увидите важную информацию (SSH-подключение, имена ресурсов)

### Создаваемые ресурсы

При выполнении команды будет развёрнута следующая инфраструктура AWS:

#### Сетевая инфраструктура (VPC)
- **VPC** с CIDR-блоком `10.10.0.0/16` в регионе `eu-central-1`
- **Публичные подсети** (для ресурсов с доступом в интернет):
  - `eks-AZ-1` (10.10.1.0/24) в зоне доступности `eu-central-1a`
  - `eks-AZ-2` (10.10.2.0/24) в зоне доступности `eu-central-1b`
- **Приватные подсети** (для внутренних ресурсов):
  - `private-subnet-1` (10.10.15.0/24) для узлов EKS в `eu-central-1a`
  - `private-subnet-2` (10.10.16.0/24) для узлов EKS в `eu-central-1b`
  - `rds-subnet-1` (10.10.21.0/24) для RDS в `eu-central-1a`
  - `rds-subnet-2` (10.10.22.0/24) для RDS в `eu-central-1b`
- **NAT Gateway** для исходящего интернет-трафика из приватных подсетей

#### Кластер EKS
- **EKS Control Plane** версии `1.34` (управляющий слой Kubernetes)
- **Fargate profile** для системных подов (kube-system, karpenter)
- **Karpenter** версии `1.8.1` (контроллер автомасштабирования)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Конфигурация Karpenter
- Контроллер Karpenter с выделенными ресурсами:
  - CPU: 0.4 ядра (requests и limits)
  - Memory: 0.5Gi (requests и limits)
- Автоматическое обнаружение подсетей через теги `karpenter.sh/discovery`

#### Дополнительные компоненты
- **Security Groups** с соответствующими правилами безопасности
- **IAM роли и политики** для Karpenter и EKS
- **OIDC provider** для интеграции с сервисами AWS

#### Основной файл конфигурации

Все параметры инфраструктуры определены в файле `tasks/eks/labs/02/env.hcl`. Для изменения конфигурации отредактируйте соответствующие параметры в этом файле.

### Предварительные требования

Убедитесь, что у вас настроено:
- **AWS CLI** с соответствующими правами доступа
- Увеличенные лимиты на количество узлов в регионе `eu-central-1` (если необходимо)

## Базовая настройка NodePool

### Проверка работы Karpenter

**Шаг 1: Подключение к рабочему узлу**

Найдите в выводе команды строку подключения SSH и подключитесь к рабочему узлу:

```bash
# Пример вывода:
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # Используйте ваш IP-адрес и пароль
```

**Шаг 2: Проверка статуса контроллера Karpenter**

Убедитесь, что контроллер Karpenter запущен и работает:

```bash
kubectl get po -n karpenter
```

**Ожидаемый результат:**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**Шаг 3: Проверка существующих NodePool и EC2NodeClass**

Проверьте, что пока нет созданных NodePool:

```bash
kubectl get nodepools
```

**Результат:**
```
No resources found
```

Проверьте EC2NodeClass:

```bash
kubectl get ec2nodeclasses
```

**Результат:**
```
No resources found
```

**Что это значит:** NodePool и EC2NodeClass — это основные ресурсы Karpenter. NodePool определяет, какие узлы создавать, а EC2NodeClass — как их настраивать (AMI, подсети, security groups и т.д.).

### Создание тестового приложения

Развернём простое тестовое приложение:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Результат:**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**Шаг 4: Проверка состояния подов**

Проверьте статус созданных подов:

```bash
kubectl get po -n team-19
```

**Результат:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**Обратите внимание:** Под находится в статусе `Pending` (ожидание). Это нормально на данном этапе.

**Шаг 5: Диагностика проблемы**

Посмотрим подробную информацию о поде:

```bash
kubectl describe po -n team-19
```

**Важная часть вывода:**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**Объяснение проблемы:**
- Под не может быть запланирован ни на одном узле
- Все 3 существующих узла — это Fargate-узлы для системных подов (kube-system, karpenter)
- Fargate profile настроен только для определённых namespace, и `team-19` в него не входит
- Нам нужно создать NodePool, чтобы Karpenter мог создать подходящие EC2-узлы

### Создание NodePool и EC2NodeClass

**Шаг 6: Создание NodePool**

NodePool определяет параметры узлов, которые будет создавать Karpenter:

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # Метка для идентификации узлов
    spec:
      requirements:
        # Поддерживаемые архитектуры процессора
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # Операционная система
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # Тип инстансов: spot (дешевле) или on-demand (стабильнее)
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # Категории инстансов (t - burstable, m - general purpose, r - memory optimized)
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # Поколение инстансов (больше 2 = более новые)
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # Размеры инстансов
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # Ссылка на EC2NodeClass с настройками AWS
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # Время жизни узла (30 дней)
      expireAfter: 720h # 30 * 24h = 720h
  # Лимиты ресурсов для всего NodePool
  limits:
    cpu: 4  # Максимум 4 CPU для всех узлов в этом pool
  # Настройки консолидации (оптимизации)
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # Удалять пустые или недоиспользуемые узлы
    consolidateAfter: 30s  # Через 30 секунд после того, как узел стал пустым
EoF

kubectl apply -f default-nodepool.yaml
```

**Шаг 7: Получение параметров из вывода Terraform**

Найдите в выводе команды `make run_eks_task` следующие значения:

```bash
# Пример вывода:
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Шаг 8: Создание EC2NodeClass**

EC2NodeClass определяет AWS-специфичные настройки узлов:

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # IAM роль для узлов (замените на вашу из вывода Terraform)
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # Выбор AMI образа
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023, последняя версия
  # Выбор подсетей по тегам
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Замените на имя вашего кластера
  # Выбор security groups по тегам
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Замените на имя вашего кластера
  # Теги для создаваемых EC2 инстансов
  tags:
      Name: "eks2-viktor-01-default"  # Замените на имя вашего кластера
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # Замените на имя вашего кластера
  # Настройка дисков
  blockDeviceMappings:
    - deviceName: /dev/xvda    # Корневой диск
      ebs:
        volumeType: gp3        # Тип диска (gp3 - современный, производительный)
        volumeSize: 25Gi       # Размер диска
        iops: 3000             # IOPS для gp3
        throughput: 125        # Пропускная способность MiB/s
        encrypted: true        # Шифрование диска
        deleteOnTermination: true  # Удалять диск при удалении инстанса
EoF

kubectl create -f default-nodeclass.yaml
```

### Проверка автоматического создания узлов

**Шаг 9: Проверка статуса ресурсов**

Проверьте, что EC2NodeClass создан и готов:

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Ожидаемый результат:**
```
NAME      READY   AGE
default   True    2m17s
```

Проверьте NodePool:

```bash
kubectl get nodepools.karpenter.sh
```

**Ожидаемый результат:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**Если статус не READY:**

Выполните диагностику EC2NodeClass:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**Пример успешного вывода:**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

Проверьте NodePool:

```bash
kubectl describe nodepools.karpenter.sh default
```

**Если есть ошибки, проверьте логи контроллера:**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Пример успешных логов:**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**Шаг 10: Проверка NodeClaim**

NodeClaim — это запрос на создание узла. Karpenter создаёт NodeClaim, который затем превращается в реальный EC2-инстанс:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**Что мы видим:**
- Создан NodeClaim с именем `default-c549s`
- Выбран инстанс типа `t3a.small` (2 vCPU, 2GB RAM)
- Используется spot-инстанс (дешевле)
- Узел находится в зоне `eu-central-1a`

**Шаг 11: Проверка пода приложения**

Теперь под должен успешно запуститься:

```bash
kubectl get po -n team-19
```

**Результат:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**Статус изменился на `Running`!**

**Шаг 12: Проверка узлов кластера**

Посмотрим все узлы в кластере:

```bash
kubectl get no
```

**Результат:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**Обратите внимание:**
- Первые 3 узла — Fargate (для системных подов)
- Последний узел — EC2-инстанс, созданный Karpenter

### Проверка автоматического удаления узлов

**Шаг 13: Удаление приложения**

Удалим наше приложение:

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Результат:**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**Шаг 14: Проверка удаления подов**

```bash
kubectl get po -n team-19
```

**Результат:**
```
No resources found in team-19 namespace.
```

**Шаг 15: Ожидание удаления NodeClaim**

Подождите примерно 30 секунд (значение `consolidateAfter` в NodePool) и проверьте:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
No resources found
```

**Karpenter автоматически удалил NodeClaim, так как узел стал пустым!**

**Шаг 16: Проверка узлов**

```bash
kubectl get no
```

**Результат:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**EC2-узел удалён! Остались только Fargate-узлы.**

**Вывод:** Karpenter автоматически управляет жизненным циклом узлов — создаёт их при необходимости и удаляет, когда они больше не нужны, оптимизируя затраты.


## Масштабирование приложений

В этом разделе мы изучим, как Karpenter автоматически добавляет узлы при увеличении нагрузки.

### Горизонтальное масштабирование

**Шаг 1: Развёртывание тестового приложения**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**Шаг 2: Проверка созданных ресурсов**

Проверьте NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

Проверьте узлы:

```bash
kubectl get no
```

**Результат:**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

Проверьте поды:

```bash
kubectl get po -n team-19
```

**Результат:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### Автоматическое добавление узлов

**Шаг 3: Масштабирование до 6 реплик**

Увеличим количество реплик приложения:

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**Результат:**
```
deployment.apps/team19 scaled
```

**Шаг 4: Проверка состояния подов**

```bash
kubectl get po -n team-19
```

**Результат:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**Все 6 подов успешно запущены!**

**Шаг 5: Проверка NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Обратите внимание:** Karpenter автоматически добавил второй узел (`default-gm8sj`), так как одного узла было недостаточно для размещения всех 6 подов.

**Шаг 6: Масштабирование до 16 реплик**

Увеличим нагрузку ещё больше:

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**Шаг 7: Проверка состояния подов**

```bash
kubectl get po -n team-19
```

**Результат:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**Проблема:** Некоторые поды находятся в статусе `Pending`. Почему? Перейдём к следующему разделу, чтобы разобраться.

## Ограничение ресурсов

В этом разделе мы разберёмся, почему некоторые поды остались в статусе `Pending`, и научимся управлять лимитами ресурсов в NodePool.

### Настройка лимитов CPU

**Шаг 1: Проверка текущих лимитов NodePool**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**Результат:**
```json
{
  "cpu": 4
}
```

**Что это значит:** В NodePool установлен лимит в 4 CPU. Это означает, что суммарное количество CPU всех узлов в этом pool не может превышать 4 ядра.

**Шаг 2: Проверка существующих NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**Анализ:**
- У нас 2 узла типа `t4g.small`
- Каждый `t4g.small` имеет 2 vCPU
- Итого: 2 узла × 2 vCPU = 4 vCPU
- **Мы достигли лимита!** Karpenter не может создать больше узлов.

### Диагностика проблем с лимитами

**Шаг 3: Проверка логов Karpenter**

Посмотрим, что говорят логи контроллера:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**Результат:**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**Ключевое сообщение:** `"all available instance types exceed limits for nodepool"`

Это подтверждает, что Karpenter не может создать новые узлы из-за лимита CPU.

**Шаг 4: Увеличение лимита CPU**

Увеличим лимит CPU до 6 ядер:

```bash
kubectl edit nodepools.karpenter.sh default
```

Найдите секцию `limits` и измените значение:

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # Измените на 6
```

Сохраните изменения (`:wq` в vim или Ctrl+O, Enter, Ctrl+X в nano).

**Шаг 5: Проверка создания нового узла**

Подождите несколько секунд и проверьте NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**Отлично!** Karpenter создал третий узел (`default-gpgn9`).

**Шаг 6: Проверка подов приложения**

```bash
kubectl get po -n team-19
```

**Результат:**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**Все 16 подов теперь в статусе `Running`!**

### Проверка автоматической консолидации

**Шаг 7: Уменьшение количества реплик**

Уменьшим количество реплик до 3:

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**Шаг 8: Мониторинг логов Karpenter**

Следите за логами в реальном времени:

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Вы увидите сообщения о консолидации:**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**Что происходит:**
- Karpenter обнаружил недоиспользуемый узел (`underutilized`)
- Принял решение удалить узел (`decision: delete`)
- Сначала помечает узел taint'ом `karpenter.sh/disrupted:NoSchedule`
- Перемещает поды на другие узлы
- Удаляет узел

**Шаг 9: Проверка оставшихся узлов**

Подождите около минуты и проверьте:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**Остался только один узел!** Karpenter удалил лишние узлы, оптимизировав затраты.

### Дополнительная информация о лимитах

Лимиты можно устанавливать на различные типы ресурсов:
- **cpu** — количество процессорных ядер
- **memory** — объём оперативной памяти
- **gpu** — количество GPU (для ML/AI нагрузок)
- **nodes** — максимальное количество узлов

**Пример конфигурации с несколькими лимитами:**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

Подробнее о лимитах читайте в [официальной документации Karpenter](https://karpenter.sh/docs/concepts/nodepools/#speclimits).


## Управление жизненным циклом узлов (Disruption)

Karpenter поддерживает автоматическое управление жизненным циклом узлов через параметр `consolidateAfter` в спецификации NodePool.

**Ключевые концепции:**

- **consolidateAfter** — время ожидания перед удалением узла после того, как он стал пустым или недоиспользуемым
- **consolidationPolicy** — политика консолидации:
  - `WhenEmpty` — удалять только полностью пустые узлы
  - `WhenEmptyOrUnderutilized` — удалять пустые и недоиспользуемые узлы (рекомендуется)

**Пример конфигурации:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # Удалять через 30 секунд после освобождения
```

**Как это работает:**

1. Karpenter постоянно мониторит использование ресурсов на узлах
2. Когда узел становится пустым или недоиспользуемым, Karpenter запускает таймер
3. Если через указанное время (`consolidateAfter`) узел всё ещё не нужен, Karpenter:
   - Помечает узел taint'ом `karpenter.sh/disrupted:NoSchedule`
   - Gracefully перемещает поды на другие узлы
   - Удаляет узел

**Дополнительные параметры:**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # Не удалять более 10% узлов одновременно
```

Подробнее о disruption читайте в [официальной документации](https://karpenter.sh/docs/concepts/disruption/).

---

## Оптимизация размеров узлов (RightSizing)

Karpenter автоматически подбирает оптимальный размер узлов в зависимости от требований подов. Это называется "right-sizing" — выбор наиболее подходящего и экономичного типа инстанса.

### Автоматический подбор оптимального размера

**Шаг 1: Установка лимита CPU**

Увеличим лимит NodePool до 10 ядер:

```bash
kubectl edit nodepools.karpenter.sh default
```

Измените:

```yaml
spec:
  limits:
    cpu: 6     # Измените на 10
```

**Шаг 2: Развёртывание приложения с большими требованиями**

Развернём приложение, которое запрашивает 3 CPU:

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Шаг 3: Проверка созданного NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**Обратите внимание:** Karpenter выбрал инстанс `t3.xlarge` с 4 vCPU, так как под запрашивает 3 CPU.

**Шаг 4: Проверка деталей узла**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**Важные метки:**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### Замена узлов при изменении требований

**Шаг 5: Уменьшение требований пода**

Изменим требования по CPU в deployment:

```bash
kubectl edit deployments.apps -n team-19 team19
```

Найдите секцию `resources` и измените:

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # Измените на "50m" (50 милликор)
        memory: 500Mi
```

Сохраните изменения.

**Шаг 6: Мониторинг логов Karpenter**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**Вы увидите:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**Что происходит:**
- Karpenter обнаружил, что узел недоиспользуется (`underutilized`)
- Принял решение заменить узел (`decision: replace`)
- Создаёт новый, более дешёвый узел

**Создание нового NodeClaim:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**Запуск нового инстанса:**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**Шаг 7: Проверка нового NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**Отлично!** Karpenter заменил `t3.xlarge` (4 vCPU) на `t4g.small` (2 vCPU), что значительно дешевле.

**Шаг 8: Очистка**

Удалите deployment:

```bash
kubectl delete deployments.apps -n team-19 team19
```

Дождитесь удаления NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
No resources found
```

**Вывод:** Karpenter автоматически оптимизирует размеры узлов, выбирая наиболее экономичные варианты, соответствующие требованиям приложений.


## Обновление конфигурации узлов (Drift)

Drift — это механизм автоматического обновления узлов при изменении конфигурации EC2NodeClass. Когда вы изменяете AMI, security groups, user data или другие параметры, Karpenter автоматически заменяет существующие узлы на новые с обновлённой конфигурацией.

### Обновление AMI образов

**Шаг 1: Получение AMI предыдущей версии EKS**

Получим AMI ID для EKS версии 1.33:

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**Результат:**
```
ami-0fc1cdef3ebc3a8fe
```

**Шаг 2: Установка старого AMI в EC2NodeClass**

Отредактируйте EC2NodeClass:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Найдите секцию `amiSelectorTerms` и измените:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Было
```

На:

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # Конкретный AMI ID версии 1.33
```

**Шаг 3: Развёртывание приложения**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-122/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**Шаг 4: Проверка версии узла**

```bash
kubectl get no
```

**Результат:**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- Версия 1.33!
```

**Обратите внимание:** Узел использует Kubernetes версии 1.33.5 (из старого AMI).

### Автоматическая миграция на новые версии

**Шаг 5: Возврат к автоматическому выбору AMI**

Отредактируйте EC2NodeClass обратно:

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

Измените на:

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # Автоматический выбор последней версии
```

**Что происходит:**
- Karpenter обнаруживает изменение в EC2NodeClass
- Определяет, что существующий узел использует устаревшую конфигурацию (drift)
- Автоматически создаёт новый узел с обновлённым AMI
- Gracefully перемещает поды на новый узел
- Удаляет старый узел

**Шаг 6: Проверка обновления узла**

Подождите около минуты и проверьте узлы:

```bash
kubectl get no
```

**Результат (через ~30 секунд):**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- Новая версия!
```

**Результат (через ~4 минуты):**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**Отлично!** Karpenter автоматически заменил узел на новый с обновлённой версией AMI (1.34.2).

**Шаг 7: Очистка**

```bash
kubectl delete deployments.apps -n team-19 team19
```

Дождитесь удаления NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
No resources found
```

**Вывод:** Drift позволяет автоматически обновлять узлы при изменении конфигурации без ручного вмешательства. Это особенно полезно для:
- Обновления AMI (патчи безопасности, новые версии Kubernetes)
- Изменения security groups
- Обновления user data скриптов
- Изменения IAM ролей

---

## Работа с несколькими NodePool

В production-среде часто требуется разделять нагрузку по разным группам узлов. Например:
- Ingress-контроллеры на выделенных узлах
- Мощные узлы для периодических задач (jobs)
- Узлы с GPU для ML/AI нагрузок
- Узлы с большим объёмом памяти для баз данных

### Изоляция нагрузки через Taints и Tolerations

**Сценарий:** Нам нужно запускать периодические job с большими требованиями по ресурсам (CPU, память, GPU).

**Требования:**
1. На эти узлы не должны попадать обычные поды (только job)
2. Пока на узле работает job, не должна происходить консолидация
3. Как только job завершается, узел должен быть удалён

### Специализированные узлы для Job

**Шаг 1: Создание специализированного NodePool**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # Метка для идентификации
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 дней
      # ВАЖНО: Taint предотвращает запуск обычных подов на этих узлах
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # Поды без соответствующего toleration не смогут запуститься
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # Удалять ТОЛЬКО пустые узлы (не во время работы job)
    consolidateAfter: 10s           # Быстрое удаление после завершения job
EoF

kubectl apply -f job-nodepool.yaml
```

**Ключевые отличия от default NodePool:**

1. **Taints** — предотвращают запуск обычных подов:
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — узел удаляется только когда полностью пуст (не прерывает работающие job)

3. **consolidateAfter: 10s** — быстрое удаление после завершения

**Шаг 2: Получение параметров из вывода Terraform**

Найдите в выводе:

```bash
# Пример:
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**Шаг 3: Создание EC2NodeClass для job**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # Замените на ваш
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Замените на имя вашего кластера
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # Замените на имя вашего кластера
  tags:
      Name: "eks2-viktor-01-job"  # Замените на имя вашего кластера
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```

**Шаг 4: Проверка статуса ресурсов**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**Результат:**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**Результат:**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**Если статус не READY**, выполните диагностику:

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**Шаг 5: Запуск Job с Toleration**

Создайте job, который может запуститься на узлах с taint `workType=job`:

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # Toleration позволяет поду запуститься на узлах с соответствующим taint
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # Affinity гарантирует, что под запустится именно на узлах job NodePool
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**Шаг 6: Проверка создания NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**Результат:**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**Проверка пода:**

```bash
kubectl get po
```

**Результат (во время выполнения):**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**Результат (после завершения):**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**Проверка узлов:**

```bash
kubectl get no
```

**Результат:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**Шаг 7: Проверка автоматического удаления узла**

Подождите примерно 10-15 секунд после завершения job и проверьте узлы:

```bash
kubectl get no
```

**Результат:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Узел успешно удалён!** Karpenter автоматически удалил узел через 10 секунд после завершения job.

**Вывод:** Использование нескольких NodePool с taints и tolerations позволяет:
- Изолировать разные типы нагрузки
- Оптимизировать затраты (быстрое удаление узлов после завершения job)
- Предотвратить запуск обычных подов на специализированных узлах
- Гибко управлять политиками консолидации для разных типов нагрузки



## Очистка ресурсов

После завершения лабораторной работы необходимо удалить все созданные ресурсы, чтобы избежать ненужных расходов.

**Шаг 1: Проверка отсутствия активных NodeClaim**

Убедитесь, что нет активных NodeClaim:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Ожидаемый результат:**
```
No resources found
```

**Если есть активные NodeClaim:**

1. Проверьте, нет ли запущенных подов на узлах:

```bash
kubectl get pods --all-namespaces -o wide
```

2. Удалите deployment, pods или jobs:

```bash
# Пример удаления deployment
kubectl delete deployment -n team-19 team19

# Пример удаления job
kubectl delete job testjob
```

3. После удаления подов удалите NodeClaim вручную (если необходимо):

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**Шаг 2: Проверка узлов кластера**

Убедитесь, что остались только Fargate-узлы:

```bash
kubectl get no
```

**Ожидаемый результат:**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**Все узлы должны начинаться с `fargate-`.**

**Шаг 3: Удаление инфраструктуры**

Удалите все ресурсы, созданные для лабораторной работы:

```bash
TASK=02 make delete_eks_task
```

**Вывод команды:**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**Введите `y` для подтверждения удаления.**

**Что будет удалено:**
- Рабочий узел (worker)
- Karpenter контроллер и связанные ресурсы
- SSH ключи
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC и сетевая инфраструктура

**Процесс удаления займёт примерно 10-15 минут.**

---

## Заключение

Поздравляем! Вы успешно завершили лабораторную работу по основам Karpenter.

**Что вы изучили:**

1. **Базовая настройка** — создание NodePool и EC2NodeClass для автоматического управления узлами
2. **Автоматическое масштабирование** — Karpenter динамически добавляет узлы при увеличении нагрузки
3. **Управление лимитами** — контроль максимального количества ресурсов через limits
4. **Консолидация** — автоматическое удаление пустых и недоиспользуемых узлов для оптимизации затрат
5. **Right-sizing** — автоматический подбор оптимального размера узлов в зависимости от требований подов
6. **Drift** — автоматическое обновление узлов при изменении конфигурации (AMI, security groups и т.д.)
7. **Множественные NodePool** — изоляция разных типов нагрузки через taints, tolerations и affinity

**Ключевые преимущества Karpenter:**

- **Быстрое масштабирование** — узлы создаются за секунды, а не минуты
- **Оптимизация затрат** — автоматический выбор наиболее экономичных типов инстансов
- **Гибкость** — поддержка spot и on-demand инстансов, различных архитектур (amd64, arm64)
- **Простота** — декларативная конфигурация через Kubernetes-ресурсы
- **Автоматизация** — минимальное ручное вмешательство в управление узлами

**Дополнительные ресурсы:**

- [Официальная документация Karpenter](https://karpenter.sh/docs/)
- [Best Practices для Karpenter](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [Troubleshooting Guide](https://karpenter.sh/docs/troubleshooting/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

**Следующие шаги:**

- Изучите продвинутые возможности Karpenter (weighted NodePools, custom AMI, GPU support)
- Интегрируйте Karpenter с вашими production-приложениями
- Настройте мониторинг и алертинг для Karpenter
- Оптимизируйте затраты через анализ использования spot vs on-demand инстансов

