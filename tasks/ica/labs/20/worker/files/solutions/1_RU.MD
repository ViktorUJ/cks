[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 20: эталонное решение

Установлен Istio `1.29.1`. Развернуты три рабочие нагрузки:
- `ping-pong` в пространстве имен `app` (внедрен sidecar, обслуживает приложение);
- `mesh-client` в пространстве имен `app` (внедрен sidecar, взаимодействует по mTLS);
- `legacy-client` в пространстве имен `legacy` (**без** sidecar, только незашифрованный трафик).

При отсутствии `PeerAuthentication` mTLS по умолчанию работает в режиме **PERMISSIVE**: как клиент mesh
(mTLS), так и устаревший клиент (незашифрованный трафик) могут обращаться к приложению.

## Цель

Перевести пространство имен `app` на **STRICT** mTLS, чтобы принимался только трафик mTLS, не
нарушив работу клиента внутри mesh.

## Шаг 1. Наблюдение базового состояния PERMISSIVE

```bash
# in-mesh client -> app : works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : ALSO works under PERMISSIVE
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200
```

## Шаг 2. (рекомендуется) Явно задать намерение с помощью PERMISSIVE

Безопасная миграция сначала явно фиксирует PERMISSIVE, а затем переключается на STRICT после того,
как вы подтвердите (по метрикам), что незашифрованный трафик отсутствует:

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

## Шаг 3. Переключение пространства имен на STRICT

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

## Шаг 4. Проверка

```bash
# in-mesh client -> app : still works (mTLS)
kubectl exec -n app deploy/mesh-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# legacy plaintext client -> app : now rejected (connection reset)
kubectl exec -n legacy deploy/legacy-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" --max-time 10 http://ping-pong.app.svc.cluster.local:8080/
# -> 000 (curl exit 56: reset by peer)
```

## Как это работает

- **PeerAuthentication** определяет, как sidecar на *стороне сервера* принимает входящие
  подключения:
  - `PERMISSIVE` (значение mesh по умолчанию) принимает как mTLS, так и незашифрованный трафик. Это
    обеспечивает миграцию без простоя: можно постепенно подключать рабочие нагрузки к mesh,
    пока устаревшие клиенты с незашифрованным трафиком продолжают работать.
  - `STRICT` принимает только mTLS; подключения с незашифрованным трафиком сбрасываются.
- Иерархия области действия: `PeerAuthentication` в `istio-system` (корневая область) применяется
  ко всей mesh; объект в пространстве имен переопределяет его для этого пространства; объект с
  `selector` переопределяет его для каждой рабочей нагрузки.
- **Рецепт безопасной миграции**: оставьте PERMISSIVE, отслеживайте метрику
  `istio_requests_total{connection_security_policy="none"}`, пока она не снизится до нуля
  (незашифрованного трафика не осталось), затем переключитесь на STRICT.

## Связанные материалы

В лабораторной работе 04 рассматривается конечное состояние STRICT в сочетании с `AuthorizationPolicy`
(кто может к кому обращаться). Эта лабораторная работа посвящена самому переходу и роли PERMISSIVE.
