# k8s-svc-sync
[English version ](README.MD) 

## Описание

`k8s-svc-sync` - это сервис для синхронизации EKS(Kubernetes) сервисов и их endpoints между двумя кластерами в реальном времени.

Программа работает с использованием механизма leader election для обеспечения высокой доступности.

## Пререквизиты
- VPC, в которых находятся оба кластера, имеют сетевую связность (например, через VPC Peering или Transit Gateway,etc )
- CIDR областей VPC не пересекаются
- используется Amazon VPC CNI и поды имеют IP адреса из VPC CIDR
- Установлен `kubectl` и настроен доступ к обоим кластерам

## Основные возможности

- **Синхронизация сервисов** между source и destination кластерами,  и различными неймспейсами
- **Селективная синхронизация** на основе меток (labels)
- **Leader Election** для обеспечения работы только одного активного экземпляра
- **Поддержка ExternalName сервисов** 
- **Мониторинг изменений** через Kubernetes Watch API
- **Health checks** через HTTP endpoints


## Архитектура

### Компоненты

1. **Leader Election** - использует Lease-based механизм для выбора активного экземпляра
2. **Service Watcher** - отслеживает изменения сервисов в source кластере
3. **Endpoints Watcher** - отслеживает изменения endpoints в source кластере
4. **HTTP Server** - предоставляет health, readiness и leader status endpoints
5. **Sync Engine** - выполняет синхронизацию ресурсов

### Принцип работы

```
Source Cluster                    Destination Cluster
┌─────────────┐                  ┌────────────────────┐
│   Service   │ ────────────────▶│      Service       │
│ sync=true   │                  │ sync=true-external │
└─────────────┘                  └────────────────────┘
       │                                │
       ▼                                ▼
┌─────────────┐                  ┌─────────────┐
│  Endpoints  │ ────────────────▶│  Endpoints  │
└─────────────┘                  └─────────────┘
```

## Параметры командной строки

| Параметр | По умолчанию | Описание |
|----------|--------------|----------|
| `-kubeconfig` | `$KUBECONFIG` | Путь к файлу kubeconfig |
| `-src-context` | `local-cluster` | Контекст source кластера |
| `-dst-context` | `external-cluster` | Контекст destination кластера |
| `-src-ns` | `default` | Namespace в source кластере |
| `-dst-ns` | `prod-test` | Namespace в destination кластере |
| `-sync-label` | `sync=true` | Селектор меток для синхронизации |
| `-leader-election-namespace` | `k8s-sync` | Namespace для leader election |
| `-leader-election-name` | `k8s-svc-sync-leader` | Имя для leader election |
| `-pod-name` | `$HOSTNAME` | Имя пода для leader election |

## HTTP Endpoints

### `/health`
- **Метод**: GET
- **Описание**: Проверка здоровья приложения
- **Ответ**: `200 OK` - приложение работает

### `/ready`
- **Метод**: GET  
- **Описание**: Проверка готовности к работе
- **Ответ**: 
  - `200 OK` - подключение к кластерам установлено
  - `503 Service Unavailable` - проблемы с подключением

### `/leader`
- **Метод**: GET
- **Описание**: Статус лидерства
- **Ответ**: 
  - `Leader: <pod-name>` - если экземпляр является лидером
  - `Follower` - если экземпляр не является лидером

## Развертывание



#### 1. Настройка Service Account во внешнем кластере

```bash
cd external
kubectl apply -f install_sa.yaml --context prod-madlan
```

#### 2. Генерация и применение ConfigMap с kubeconfig для локального кластера

```bash
cd ..
./generate_kubeconfig.sh
kubectl apply -f kubeconfig.yaml  # локальный кластер
```

### применяем манифесты в локальном кластере

``` 
kubectl apply -f deploy/local/
```

### Deployment характеристики

- **Replicas**: 3 экземпляра для высокой доступности
- **Anti-affinity**: Поды распределяются по разным нодам
- **Resources**: 
  - Requests: 100m CPU, 128Mi Memory
  - Limits: 1000m CPU, 512Mi Memory
- **PodDisruptionBudget**: Минимум 1 доступный под

## Логика синхронизации

### Сервисы с меткой `sync=true`

1. **Обнаружение**: Сервис помечается меткой `sync=true`
2. **Отслеживание**: Добавляется в список отслеживаемых сервисов
3. **Создание**: В destination кластере создается аналогичный сервис
4. **Синхронизация endpoints**: Endpoints автоматически обновляются

### Типы сервисов

#### ClusterIP сервисы
- Создается сервис типа ClusterIP
- Синхронизируются все порты из source сервиса
- Endpoints содержат IP адреса ready подов

#### ExternalName сервисы  
- Создается сервис типа ExternalName
- Копируется ExternalName и порты
- Endpoints не создаются

### Удаление сервисов

1. **Удаление метки**: При удалении `sync=true` сервис перестает отслеживаться и удаляется из destination кластера 
2. **Удаление сервиса**: При удалении source сервиса, удаляется destination сервис
3. **Защита**: Удаляются только сервисы с меткой `sync=true-external`

## Мониторинг и логирование

### Формат логов

```
2024-01-15 10:30:45 [pod-name] сообщение
```

### Типы событий

- **INFO**: Информационные сообщения о синхронизации
- **ERROR**: Ошибки синхронизации и подключения к кластерам

### Примеры логов

```bash
# Успешная синхронизация
2024-01-15 10:30:45 [k8s-svc-sync-abc123] [local-cluster/default/my-service → prod-cluster/prod-test/my-service] updated endpoints → 3 IPs

# Начало отслеживания сервиса
2024-01-15 10:30:46 [k8s-svc-sync-abc123] started syncing service my-service, currently tracking: [my-service, other-service]

# Leader election
2024-01-15 10:30:47 [k8s-svc-sync-abc123] became leader, starting sync operations
```

## Требования к безопасности

### RBAC права

Приложению требуются следующие права:

**Source кластер**:
- `services`: get, list, watch
- `endpoints`: get, list, watch  
- `leases`: get, list, create, update

**Destination кластер**:
- `services`: get, list, create, update, delete
- `endpoints`: get, list, create, update, delete
- `namespaces`: get, create

## Устранение неполадок

### Частые проблемы

1. **Сервис не синхронизируется**
   - Проверьте наличие метки `sync=true`
   - Убедитесь что endpoints имеют ready адреса

2. **Ошибки подключения к кластеру**
   - Проверьте kubeconfig и доступность API серверов
   - Убедитесь в корректности контекстов

3. **Leader election не работает**
   - Проверьте RBAC права для lease ресурсов
   - Убедитесь что namespace для leader election существует

### Проверка статуса

```bash
# Проверка health
curl http://localhost:8080/health

# Проверка готовности
curl http://localhost:8080/ready

# Проверка лидерства
curl http://localhost:8080/leader
```

## Пример использования

### Запуск локально

```bash
go build -o k8s-svc-sync .
./k8s-svc-sync \
  -src-context local-cluster \
  -dst-context prod-cluster \
  -src-ns default \
  -dst-ns production
```

### Маркировка сервиса для синхронизации

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  labels:
    sync: "true"  # Эта метка включает синхронизацию
spec:
  selector:
    app: my-app
  ports:
  - port: 80
    targetPort: 8080
```