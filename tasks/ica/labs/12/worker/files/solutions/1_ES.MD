[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 12 - Solución de referencia (Resolución de problemas)

El entorno viene con errores preexistentes. Dos errores:
- **ERROR 1** - el espacio de nombres `default` no está habilitado para la inyección de sidecar (ping-pong está en `1/1`).
- **ERROR 2** - el VirtualService enruta al subconjunto `v2`, que el DestinationRule no define (solo `v1`) → el gateway devuelve `503`.

## Diagnóstico

```bash
# 1) run the static analyzer - it reports both problems
istioctl analyze -n default
#  - IST0102: namespace default not enabled for injection
#  - referenced subset "v2" not found in DestinationRule

# 2) confirm the missing sidecar
kubectl get pods -n default            # ping-pong is 1/1

# 3) confirm the routing failure
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/   # 503

# 4) inspect the ingress gateway routes/clusters - the v2 cluster has no endpoints
GW=$(kubectl -n istio-system get pod -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config routes   "$GW.istio-system" | grep -i myapp || true
istioctl proxy-config clusters "$GW.istio-system" | grep ping-pong

# 5) check proxy sync status
istioctl proxy-status
```

## Corrección del ERROR 1 - habilitar la inyección

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl rollout restart deployment ping-pong -n default
kubectl get pods -n default            # now 2/2
```

## Corrección del ERROR 2 - dirigir el VirtualService a un subconjunto existente

```bash
kubectl patch virtualservice ping-pong-vs -n default --type=json \
  -p='[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value":"v1"}]'
```

(equivalente: edite `ping-pong-vs` y cambie `subset: v2` → `subset: v1`; o añada un subconjunto `v2` al DestinationRule.)

## Verificación

```bash
istioctl analyze -n default                                          # no issues
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/   # 200
kubectl get pods -n default                                          # 2/2
```
