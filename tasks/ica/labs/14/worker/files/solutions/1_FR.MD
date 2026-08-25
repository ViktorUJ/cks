[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 14 - Solution de référence (Basculement sensible à la localité)

Le cluster possède deux nœuds dans des zones différentes (`eu-central-1a`, `eu-central-1b`),
déjà étiquetés avec `topology.kubernetes.io/zone` par le bootstrap.

## Étape 1. Confirmer les étiquettes de zone

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

## Étape 2. Activer l'injection de sidecar et déployer l'application

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/14/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods -n default -o wide     # ping-pong-a on zone a, ping-pong-b on zone b
```

## Étape 3. DestinationRule - équilibrage de charge par localité + détection des valeurs aberrantes

Le basculement de localité nécessite `outlierDetection` (pour détecter les points de terminaison non sains) et
`localityLbSetting` (pour activer le routage sensible à la localité).

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

## Étape 4. Observer la préférence de localité

Le client est dans la zone A, il est donc servi par le backend de la zone A :

```bash
for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-A   (x5)
```

## Étape 5. Déclencher le basculement

Arrêtez le backend local (Zone-A) : le trafic bascule vers Zone-B :

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
