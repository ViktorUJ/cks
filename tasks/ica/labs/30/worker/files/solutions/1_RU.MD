[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 30 - Эталонное решение

Установлен Istio `1.29.1`. Пространство имен `app` (istio-injection) содержит клиент
`app-client` внутри mesh. `istioctl` доступен на рабочем ПК.

## Цель

Запустить **StatefulSet** за **headless Service** в mesh, включить **STRICT** mTLS
и обращаться к каждой реплике по ее **стабильной идентичности для каждого pod** (`web-0`, `web-1`) через mTLS.

## Шаг 1. Headless Service + StatefulSet

У Service должен быть `clusterIP: None` (headless), а также **именованный** порт (Istio использует
префикс имени порта для определения протокола). `serviceName` StatefulSet должен совпадать с
headless Service, чтобы pod получали стабильные DNS-имена `<pod>.<svc>.<ns>.svc.cluster.local`.

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: app
  labels:
    app: web
spec:
  clusterIP: None          # headless
  selector:
    app: web
  ports:
    - name: http           # named port - required for Istio protocol detection
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
  namespace: app
spec:
  serviceName: web         # ties the pods to the headless Service
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: viktoruj/ping_pong:latest
          env:
            - name: ENABLE_DEFAULT_HOSTNAME   # report the real pod name (web-0/web-1)
              value: "false"
          ports:
            - name: http
              containerPort: 8080
EOF

kubectl rollout status statefulset/web -n app
```

## Шаг 2. Принудительно включите STRICT mTLS

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: STRICT
EOF
```

## Шаг 3. Обращение к каждой реплике по ее стабильной идентичности (через mTLS)

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-0.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-0

kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-1.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-1
```

Каждое стабильное DNS-имя разрешается в конкретный pod, а трафик шифруется mTLS
с помощью sidecar, хотя Service является headless.

## Почему headless + mesh раньше были сложным сочетанием

- У **headless** Service есть `clusterIP: None`, поэтому виртуальный IP отсутствует: DNS возвращает
  IP-адреса отдельных pod напрямую. Приложения StatefulSet часто подключаются к **конкретному** узлу
  (например, Kafka broker или реплике базы данных) по его стабильному имени, а не к VIP с балансировкой нагрузки.
- Исторически Envoy создавал listeners на `0.0.0.0:<port>`, что конфликтовало с приложениями,
  привязанными только к IP-адресу pod, а mTLS для headless services был проблематичным. **Istio
  1.10+** нативно поддерживает headless services: listeners для каждого pod и автоматический mTLS работают.
- **Именование портов по-прежнему важно**: назовите порт `http`/`tcp`/`grpc`/`mongo-*` и т. д. Безымянный
  порт заставляет Istio рассматривать его как непрозрачный TCP, и вы теряете возможности L7.

## Внешние headless services (бонус)

Для headless service, находящегося **вне** кластера (например, внешнего Kafka), добавьте
`ServiceEntry` с `resolution: DNS`, чтобы mesh мог разрешать его и направлять к нему трафик:

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: kafka-ext
  namespace: app
spec:
  hosts: ["kafka.example.com"]
  location: MESH_INTERNAL
  ports:
    - name: tcp-kafka
      number: 9092
      protocol: TCP
  resolution: DNS
```
