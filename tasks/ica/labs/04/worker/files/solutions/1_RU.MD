[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 04 - Эталонное решение

## Шаг 1. Включите инъекцию сайдкара в `default`

```bash
kubectl label namespace default istio-injection=enabled --overwrite
# legacy namespace stays WITHOUT injection on purpose
```

## Шаг 2. Разверните приложение

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/04/k8s-1/scripts/1.yaml
# restart any pods created before the label was applied
kubectl rollout restart deployment -n default
```

## Шаг 3. Точка входа: Gateway + frontend VirtualService

```yaml
# gateway.yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "myapp.local"
---
# frontend-vs.yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: frontend-vs
  namespace: default
spec:
  hosts:
  - "myapp.local"
  gateways:
  - main-gateway
  http:
  - route:
    - destination:
        host: frontend
        port:
          number: 8080
```

```bash
kubectl apply -f gateway.yaml
kubectl apply -f frontend-vs.yaml
```

## Шаг 4. STRICT mTLS (PeerAuthentication)

```yaml
# peer-auth.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f peer-auth.yaml
```

Убедитесь, что устаревший клиент с открытым текстом теперь отклоняется:

```bash
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 5 http://ping-pong.default:8080/
# connection reset / empty -> blocked
```

## Шаг 5. Запрет по умолчанию для бэкенда (AuthorizationPolicy)

```yaml
# deny-all.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: ping-pong-deny-all
  namespace: default
spec:
  selector:
    matchLabels:
      app: ping-pong
  action: ALLOW
  # no rules => every request to ping-pong is denied (403)
```

```bash
kubectl apply -f deny-all.yaml
```

## Шаг 6. Разрешите только идентификатор frontend с GET

```yaml
# allow-frontend.yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: ping-pong-allow-frontend
  namespace: default
spec:
  selector:
    matchLabels:
      app: ping-pong
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/frontend"]
    to:
    - operation:
        methods: ["GET"]
```

```bash
kubectl apply -f allow-frontend.yaml
```

## Проверка

```bash
# frontend (allowed) -> 200
curl -s http://myapp.local:32080 | grep 'Backend Status'

# unauthorized (wrong identity) -> 403
kubectl exec -n default deploy/unauthorized -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong:8080/
```
