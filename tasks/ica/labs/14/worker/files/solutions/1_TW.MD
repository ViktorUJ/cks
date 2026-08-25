[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 14 - 參考解答（具本地性意識的容錯移轉）

叢集有兩個位於不同區域的節點（`eu-central-1a`、`eu-central-1b`），
且已在啟動程序期間標記 `topology.kubernetes.io/zone`。

## 步驟 1. 確認區域標籤

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

## 步驟 2. 啟用 sidecar 注入並部署應用程式

```bash
kubectl label namespace default istio-injection=enabled --overwrite
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/14/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n default
kubectl get pods -n default -o wide     # ping-pong-a on zone a, ping-pong-b on zone b
```

## 步驟 3. DestinationRule - 本地性 LB 與異常值偵測

本地性容錯移轉需要 `outlierDetection`（用於偵測不健康的端點）和
`localityLbSetting`（用於啟用本地性意識路由）。

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

## 步驟 4. 觀察本地性偏好

用戶端位於區域 A，因此由區域 A 的後端提供服務：

```bash
for i in $(seq 5); do
  kubectl exec -n default deploy/curl-client -c curl -- curl -s http://ping-pong:8080/ | grep 'Server Name';
done
# Server Name: Zone-A   (x5)
```

## 步驟 5. 觸發容錯移轉

將本機（區域 A）後端下線，流量會容錯移轉至區域 B：

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
