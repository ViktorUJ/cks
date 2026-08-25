[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 24 - Эталонное решение

Istio `1.29.1` установлен в режиме **ambient** (istiod + istio-cni + ztunnel). Пространство имён
`app` подключено к ambient (`istio.io/dataplane-mode: ambient`) и запускает
`ping-pong` и `app-client` - оба **без** sidecar. `istioctl` доступен на
рабочем ПК.

## Предыстория

- **ztunnel** предоставляет каждой workload в ambient L4 mTLS и идентификацию, но **не**
  понимает HTTP. Поэтому политики L4 (разрешение/запрет по идентификации/порту) работают, но правила L7
  (методы HTTP, пути, заголовки) не работают.
- Для применения политики **L7** добавьте **waypoint proxy** - Envoy для пространства имён (или
  сервиса), через который маршрутизируется трафик ambient для обработки L7.

## Цель

Добавьте waypoint в пространство имён `app` и L7 `AuthorizationPolicy`, разрешающую только
запросы `GET` к `ping-pong` (всё остальное → `403`).

## Шаг 1. Подготовьте waypoint

```bash
istioctl waypoint apply -n app --enroll-namespace
kubectl get gtw waypoint -n app
kubectl rollout status deploy/waypoint -n app
```

`--enroll-namespace` добавляет метку пространству имён (`istio.io/use-waypoint: waypoint`), поэтому трафик
к сервисам в `app` маршрутизируется через waypoint.

## Шаг 2. Примените L7 AuthorizationPolicy

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: app
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: waypoint
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
EOF
```

Политика `ALLOW` запрещает по умолчанию всё, чему она не соответствует, поэтому проходит только `GET`;
другие методы получают `403`.

## Шаг 3. Проверьте

```bash
# GET -> allowed
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X GET http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# DELETE -> denied by the waypoint
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE http://ping-pong.app.svc.cluster.local:8080/
# -> 403
```

## Как это работает

- **L4 без sidecar (ztunnel)** обрабатывает mTLS и идентификацию для всего пространства имён без
  proxy на уровне pod. Он экономичен и всегда включён в ambient.
- **Waypoint (L7)** добавляется только там, где необходимы возможности на уровне HTTP: авторизация L7,
  маршрутизация, повторы, разделение трафика. Envoy требуется только для этих сервисов.
- `AuthorizationPolicy` через `targetRefs` ссылается на `Gateway` waypoint, поэтому она применяется на
  этапе L7. Та же политика, прикреплённая к sidecar/ingress, тоже работает - ambient лишь переносит
  точку применения L7 на waypoint.
- Эта многоуровневая модель (ztunnel для L4 везде, waypoint для L7 там, где он нужен) является ключевой
  идеей ambient: более низкая базовая стоимость по сравнению с sidecar, L7 по необходимости.

## Связанные материалы

Лабораторная работа 09 охватывает основы ambient (ztunnel L4). Лабораторная работа 04 охватывает ту же `AuthorizationPolicy`
в модели sidecar.
