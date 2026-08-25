[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratoire 12 - Solution de référence (Dépannage)

L'environnement est volontairement défaillant. Deux bogues :
- **BOGUE 1** - l'injection de sidecar n'est pas activée pour l'espace de noms `default` (ping-pong est à `1/1`).
- **BOGUE 2** - le VirtualService achemine vers le sous-ensemble `v2`, que le DestinationRule ne définit pas (seul `v1` est défini) → la passerelle renvoie `503`.

## Diagnostiquer

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

## Corriger le BOGUE 1 - activer l'injection

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl rollout restart deployment ping-pong -n default
kubectl get pods -n default            # now 2/2
```

## Corriger le BOGUE 2 - diriger le VirtualService vers un sous-ensemble existant

```bash
kubectl patch virtualservice ping-pong-vs -n default --type=json \
  -p='[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value":"v1"}]'
```

(Équivalent : modifiez `ping-pong-vs` et remplacez `subset: v2` → `subset: v1`, ou ajoutez un sous-ensemble `v2` au DestinationRule.)

## Vérifier

```bash
istioctl analyze -n default                                          # no issues
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/   # 200
kubectl get pods -n default                                          # 2/2
```
