[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 14 - Referenzlösung (lokalitätsbewusster Failover)

Der Cluster verfügt über zwei Knoten in unterschiedlichen Zonen (`eu-central-1a`, `eu-central-1b`),
die bereits durch das Bootstrap mit `topology.kubernetes.io/zone` beschriftet wurden.

## Schritt 1. Zonenlabels bestätigen

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

## Schritt 2. Sidecar-Injektion aktivieren und die App bereitstellen

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/14/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods -n default -o wide     # ping-pong-a on zone a, ping-pong-b on zone b
```

## Schritt 3. DestinationRule - Locality-LB + Ausreißererkennung

Locality-Failover erfordert `outlierDetection` (um nicht fehlerfreie Endpunkte zu erkennen) und
`localityLbSetting` (um lokalitätsbewusstes Routing zu aktivieren).

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

## Schritt 4. Lokalitätspräferenz beobachten

Der Client befindet sich in Zone A und wird daher vom Zone-A-Backend bedient:

```bash
for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-A   (x5)
```

## Schritt 5. Failover auslösen

Das lokale (Zone-A-)Backend herunterfahren - der Traffic wechselt zum Zone-B-Backend:

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
