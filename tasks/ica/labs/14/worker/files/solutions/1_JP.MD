[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 14. リファレンスソリューション（ローカリティを考慮したフェイルオーバー）

クラスターには異なるゾーン（`eu-central-1a`、`eu-central-1b`）にある2つのノードがあり、
ブートストラップによってすでに `topology.kubernetes.io/zone` のラベルが付与されています。

## ステップ 1. ゾーンラベルを確認する

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

## ステップ 2. サイドカーインジェクションを有効化し、アプリをデプロイする

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/14/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods -n default -o wide     # ping-pong-a on zone a, ping-pong-b on zone b
```

## ステップ 3. DestinationRule: ローカリティ LB と異常検知

ローカリティフェイルオーバーには、異常なエンドポイントを検知するための `outlierDetection` と、
ローカリティを考慮したルーティングを有効にするための `localityLbSetting` が必要です。

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

## ステップ 4. ローカリティの優先設定を確認する

クライアントはゾーン A にあるため、ゾーン A のバックエンドによって処理されます。

```bash
for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-A   (x5)
```

## ステップ 5. フェイルオーバーを発生させる

ローカルのゾーン A バックエンドを停止すると、トラフィックはゾーン B にフェイルオーバーします。

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
