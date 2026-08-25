[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 14 - Solución de referencia (Conmutación por error consciente de la localidad)

El clúster tiene dos nodos en zonas diferentes (`eu-central-1a`, `eu-central-1b`),
ya etiquetados con `topology.kubernetes.io/zone` durante la inicialización.

## Paso 1. Confirmar las etiquetas de zona

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

## Paso 2. Habilitar la inyección de sidecar y desplegar la aplicación

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/14/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods -n default -o wide     # ping-pong-a on zone a, ping-pong-b on zone b
```

## Paso 3. DestinationRule - balanceo de carga por localidad y detección de valores atípicos

La conmutación por error de localidad requiere `outlierDetection` (para detectar endpoints no saludables) y
`localityLbSetting` (para habilitar el enrutamiento consciente de la localidad).

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

## Paso 4. Observar la preferencia de localidad

El cliente está en la zona A, por lo que es atendido por el backend de la zona A:

```bash
for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-A   (x5)
```

## Paso 5. Activar la conmutación por error

Desactiva el backend local (zona A): el tráfico conmuta al de la zona B:

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
