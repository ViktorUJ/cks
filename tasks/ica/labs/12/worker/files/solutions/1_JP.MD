[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 12 - リファレンスソリューション（トラブルシューティング）

環境にはあらかじめ障害が設定されています。バグは2つあります。
- **BUG 1** - namespace `default` でサイドカーインジェクションが有効化されていません（ping-pong は `1/1`）。
- **BUG 2** - VirtualService は、DestinationRule で定義されていない subset `v2` にルーティングします（定義されているのは `v1` のみ） → gateway は `503` を返します。

## 診断

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

## BUG 1 の修正 - インジェクションを有効化

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl rollout restart deployment ping-pong -n default
kubectl get pods -n default            # now 2/2
```

## BUG 2 の修正 - VirtualService を既存の subset に向ける

```bash
kubectl patch virtualservice ping-pong-vs -n default --type=json \
  -p='[{"op":"replace","path":"/spec/http/0/route/0/destination/subset","value":"v1"}]'
```

（同等の方法: `ping-pong-vs` を編集して `subset: v2` を `subset: v1` に変更するか、DestinationRule に `v2` subset を追加します。）

## 検証

```bash
istioctl analyze -n default                                          # no issues
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/   # 200
kubectl get pods -n default                                          # 2/2
```
