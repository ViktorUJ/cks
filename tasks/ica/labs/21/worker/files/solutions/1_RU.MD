[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 21 - Эталонное решение

Установлен Istio `1.29.1`. Развернуты два пространства имен:
- `app` с `ping-pong` (внедрен sidecar);
- `other` с `backend` (внедрен sidecar).

По умолчанию каждый sidecar получает конфигурацию Envoy для **всех** сервисов в mesh, поэтому
прокси `app` также содержит кластер для `backend.other`, хотя никогда с ним не взаимодействует.

## Цель

Ограничить прокси пространства имен `app` ресурсом `Sidecar`, чтобы они получали конфигурацию
только для собственного пространства имен и `istio-system`.

## Шаг 1. Просмотрите конфигурацию по умолчанию (без ограничения области)

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config clusters "$POD" -n app | grep backend.other
# a cluster for backend.other.svc.cluster.local is present
```

## Шаг 2. Примените ресурс Sidecar для ограничения исходящего трафика

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

- `./*` - каждый сервис в **локальном** пространстве имен (`app`);
- `istio-system/*` - пространство имен control plane (необходимо для телеметрии и т. д.).

`Sidecar` с именем `default` без `workloadSelector` применяется ко всем рабочим нагрузкам в
пространстве имен.

## Шаг 3. Убедитесь, что конфигурация уменьшилась

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# 'other' namespace clusters are gone
istioctl proxy-config clusters "$POD" -n app | grep backend.other || echo "pruned ✅"

# own namespace clusters remain
istioctl proxy-config clusters "$POD" -n app | grep ping-pong.app
```

## Как это работает и почему это важно

- Ресурс **`Sidecar`** управляет областью конфигурации, которую istiod отправляет в прокси.
  `egress.hosts` определяет разрешенный список сервисов, о которых узнает прокси.
- По умолчанию mesh является "полной mesh": каждый прокси знает каждый сервис. В большом
  кластере (тысячи сервисов) это означает огромные конфигурации Envoy, высокое потребление памяти каждым pod
  и высокую нагрузку CPU istiod при каждом изменении.
- Ограничение области прокси ресурсами `Sidecar` является стандартным способом масштабирования Istio:
  меньшие конфигурации, более быстрые отправки, меньшая нагрузка istiod и более строгие границы исходящего трафика.
- `outboundTrafficPolicy` внутри `Sidecar` может дополнительно установить `REGISTRY_ONLY` для каждого
  пространства имен, чтобы блокировать необъявленный исходящий трафик.

> Примечание: ограничение области относится к *распространению конфигурации*, а не к авторизации. Чтобы фактически запретить
> вызовы, используйте `AuthorizationPolicy` (Лабораторная работа 04) или `outboundTrafficPolicy: REGISTRY_ONLY`.
