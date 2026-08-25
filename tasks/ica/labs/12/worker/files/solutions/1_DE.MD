[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 12 - Referenzlösung (Fehlerbehebung)

Die Umgebung ist bereits fehlerhaft vorkonfiguriert. Zwei Fehler:
- **FEHLER 1** - Der Namespace `default` ist nicht für die Sidecar-Injektion aktiviert (ping-pong ist `1/1`).
- **FEHLER 2** - Der VirtualService leitet an Subset `v2` weiter, das die DestinationRule nicht definiert (nur `v1`) → Das Gateway gibt `503` zurück.

## Diagnose

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

## FEHLER 1 beheben - Injektion aktivieren

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl rollout restart deployment ping-pong -n default
kubectl get pods -n default            # now 2/2
```

## FEHLER 2 beheben - Den VirtualService auf ein vorhandenes Subset verweisen lassen

```bash
kubectl patch virtualservice ping-pong-vs -n default --type=json \
  -p='[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value":"v1"}]'
```

(entspricht: `ping-pong-vs` bearbeiten und `subset: v2` → `subset: v1` ändern; oder ein Subset `v2` zur DestinationRule hinzufügen.)

## Überprüfen

```bash
istioctl analyze -n default                                          # no issues
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/   # 200
kubectl get pods -n default                                          # 2/2
```
