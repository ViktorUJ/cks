[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 14. Эталонное решение (отказоустойчивость с учетом локальности)

Кластер содержит два узла в разных зонах (`eu-central-1a`, `eu-central-1b`),
которые уже помечены `topology.kubernetes.io/zone` при начальной настройке.

## Шаг 1. Подтвердите метки зон

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

## Шаг 2. Включите инъекцию sidecar и разверните приложение

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/14/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods -n default -o wide     # ping-pong-a on zone a, ping-pong-b on zone b
```

## Шаг 3. DestinationRule: балансировка нагрузки по локальности и обнаружение выбросов

Для отказоустойчивости по локальности требуются `outlierDetection` (для обнаружения
нездоровых конечных точек) и `localityLbSetting` (для включения маршрутизации с учетом локальности).

```yaml
# dr.yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: ping-pong-dr
  namespace: default
spec:
  host: ping-pong
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
      localityLbSetting:
        enabled: true
    outlierDetection:
      consecutive5xxErrors: 1
      interval: 1s
      baseEjectionTime: 1m
      maxEjectionPercent: 100
```

```bash
kubectl apply -f dr.yaml
```

## Шаг 4. Проверьте предпочтение локальности

Клиент находится в зоне A, поэтому его обслуживает бэкенд зоны A:

```bash
for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-A   (x5)
```

## Шаг 5. Запустите отказоустойчивое переключение

Отключите локальный бэкенд зоны A: трафик переключится на зону B:

```bash
kubectl scale deployment ping-pong-a -n default --replicas=0
kubectl wait --for=delete pod -l app=ping-pong,zone=a -n default --timeout=60s

for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-B   (failover)

# restore
kubectl scale deployment ping-pong-a -n default --replicas=1
```
