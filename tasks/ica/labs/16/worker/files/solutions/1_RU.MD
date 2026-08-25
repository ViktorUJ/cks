[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 16 - Эталонное решение

Istio `1.29.1` уже установлен (профиль по умолчанию), а CRD Kubernetes Gateway API
(`v1.2.1`) присутствуют. Приложение (`ping-pong-v1` / `ping-pong-v2`) развернуто в
пространстве имен `app`.

## Шаг 1. Разверните приложение

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/16/k8s-1/scripts/1.yaml
kubectl get pods -n app
```

Каждый pod должен быть `2/2` (приложение + sidecar `istio-proxy`).

## Шаг 2. Создайте Gateway (Kubernetes Gateway API)

Gateway аннотирован, поэтому Istio создает для него Service типа **NodePort** (в этой
тестовой среде нет облачного балансировщика нагрузки).

```bash
cat > gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: app
  annotations:
    networking.istio.io/service-type: NodePort
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
EOF

kubectl apply -f gateway.yaml
```

Istio автоматически создает Deployment и Service с именем `web-gateway-istio` в
пространстве имен `app`:

```bash
kubectl get gateway web-gateway -n app
kubectl get deploy,svc web-gateway-istio -n app
```

## Шаг 3. Создайте HTTPRoute

Направьте запросы с заголовком `x-version: canary` на **v2**, а все остальные на **v1**.

```bash
cat > httproute.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ping-pong-route
  namespace: app
spec:
  parentRefs:
    - name: web-gateway
  rules:
    - matches:
        - headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: ping-pong-v2
          port: 8080
    - backendRefs:
        - name: ping-pong-v1
          port: 8080
EOF

kubectl apply -f httproute.yaml
```

## Шаг 4. Проверьте маршрутизацию

```bash
NODEPORT=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# default -> v1
curl -s http://myapp.local:${NODEPORT}/

# canary header -> v2
curl -s -H "x-version: canary" http://myapp.local:${NODEPORT}/
```

Ожидаемый результат: запрос по умолчанию возвращает `Ping-Pong-V1 (Stable)`, а запрос с
заголовком `x-version: canary` возвращает `Ping-Pong-V2 (Canary)`.

## Istio API и Gateway API

| Концепция | Istio API | Kubernetes Gateway API |
|---|---|---|
| Точка входа | `Gateway` (networking.istio.io) | `Gateway` (gateway.networking.k8s.io) |
| Правила маршрутизации | `VirtualService` | `HTTPRoute` |
| Бэкенд | `host` + `subset` (+ `DestinationRule`) | `backendRefs` |
| Pod Gateway | общий `istio-ingressgateway` | автоматически созданный для каждого `Gateway` |
| Переносимость | только для Istio | нейтральный к поставщику, переносимый между mesh и ingress |
