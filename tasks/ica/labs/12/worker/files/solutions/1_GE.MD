[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 12 - საცნობარო გადაწყვეტა (პრობლემების აღმოფხვრა)

გარემო წინასწარ არის დაზიანებული. ორი შეცდომა:
- **BUG 1** - namespace `default`-ისთვის sidecar-ის ინექცია არ არის ჩართული (ping-pong არის `1/1`).
- **BUG 2** - VirtualService მარშრუტს subset `v2`-ისკენ მიმართავს, რომელიც DestinationRule-ში განსაზღვრული არ არის (არის მხოლოდ `v1`) → gateway აბრუნებს `503`-ს.

## დიაგნოსტიკა

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

## BUG 1-ის გამოსწორება - ინექციის ჩართვა

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl rollout restart deployment ping-pong -n default
kubectl get pods -n default            # now 2/2
```

## BUG 2-ის გამოსწორება - VirtualService-ის არსებულ subset-ზე მიმართვა

```bash
kubectl patch virtualservice ping-pong-vs -n default --type=json \
  -p='[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value":"v1"}]'
```

(ეკვივალენტური ვარიანტი: დაარედაქტირეთ `ping-pong-vs` და შეცვალეთ `subset: v2` → `subset: v1`; ან DestinationRule-ს დაამატეთ subset `v2`.)

## შემოწმება

```bash
istioctl analyze -n default                                          # no issues
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/   # 200
kubectl get pods -n default                                          # 2/2
```
