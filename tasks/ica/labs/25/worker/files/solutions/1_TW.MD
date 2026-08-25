[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 25 - 參考解答

已安裝 Istio `1.29.1` + Prometheus。**Flagger** 在 `istio-system` 中執行。命名空間
`test`（istio-injection）包含示範應用程式 **podinfo**（`6.0.0`）、一個
**flagger-loadtester**（在分析期間產生流量），且 `istio-system` 中有一個 `public-gateway`。

## 目標

建立一個 `Canary` 資源，讓 Flagger 驅動**漸進式交付**：每當有新映像時，逐步將流量移轉至
canary、檢查指標，並自動提升（或於失敗時自動回復）。

## 步驟 1. 建立 Canary

```bash
kubectl apply -f - <<'EOF'
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 300
  autoscalerRef:
    apiVersion: autoscaling/v2
    kind: HorizontalPodAutoscaler
    name: podinfo
  service:
    port: 9898
    targetPort: 9898
    gateways:
    - istio-system/public-gateway
    hosts:
    - app.example.com
  analysis:
    interval: 30s
    threshold: 5
    maxWeight: 50
    stepWeight: 20
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
    webhooks:
    - name: load-test
      url: http://flagger-loadtester.test/
      timeout: 5s
      metadata:
        cmd: "hey -z 2m -q 10 -c 2 http://podinfo-canary.test:9898/"
EOF
```

## 步驟 2. 等待 Flagger 初始化

```bash
kubectl -n test get canary podinfo -w   # wait until STATUS = Initialized
kubectl -n test get deploy
# Flagger created: podinfo-primary, services podinfo/podinfo-canary/podinfo-primary,
# destinationrules and a virtualservice.
```

## 步驟 3. 觸發 canary 發布

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.1
```

Flagger 偵測到新修訂版本並開始分析：它將 20% → 40% → 50% 的流量逐步移轉至
canary，每個 interval 都會檢查 `request-success-rate` 和 `request-duration`。
loadtester 會持續傳送流量，因此指標會存在。

## 步驟 4. 監看提升程序

```bash
kubectl -n test describe canary/podinfo
# ... Advance podinfo.test canary weight 20/40/50
# ... Copying podinfo.test template spec to podinfo-primary.test
# ... Promotion completed!

kubectl -n test get canary podinfo         # STATUS = Succeeded
kubectl -n test get deploy podinfo-primary -o jsonpath='{.spec.template.spec.containers[*].image}'
# -> ghcr.io/stefanprodan/podinfo:6.0.1
```

使用上述設定時，提升程序大約需要 2–3 分鐘。`podinfo-primary` 更新至 `6.0.1` 後，執行
`check_result`。

## 自動回復（選用）

觸發另一個發布，並在分析期間注入失敗：

```bash
kubectl -n test set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
POD=$(kubectl -n test get pod -l app=flagger-loadtester -o jsonpath='{.items[0].metadata.name}')
kubectl -n test exec -it "$POD" -- hey -z 1m -c 5 -q 10 http://podinfo-canary.test:9898/status/500
```

當失敗的指標檢查達到 threshold 時，Flagger 會停止並回復，流量會回到 primary，canary 會縮放為零，且 STATUS 會變成 `Failed`。

## 運作方式

- Flagger 監看目標 `Deployment`。規格變更時，它會建立或更新一個
  **canary** deployment，並透過 Istio `VirtualService`/`DestinationRule` 權重逐步移轉流量。
- 每個步驟中，它會向 **Prometheus** 查詢已設定的指標；若指標維持在 threshold 範圍內則繼續，否則會在 `threshold` 次失敗後回復。
- `podinfo-primary` 始終保留「已知良好」的版本；在 canary 完全通過並獲得提升之前，實際流量會由 primary 提供服務。
- 這可將風險較高的手動 canary（Lab 06 流量移轉）轉換為具備內建回復功能、由指標把關的自動化發布，也就是漸進式交付的本質。