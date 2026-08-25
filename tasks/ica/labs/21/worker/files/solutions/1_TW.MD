[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 21 - 參考解答

已安裝 Istio `1.29.1`。已部署兩個命名空間：
- `app`，其中有 `ping-pong`（已注入 sidecar）；
- `other`，其中有 `backend`（已注入 sidecar）。

預設情況下，每個 sidecar 都會接收網格中**所有**服務的 Envoy 設定，因此即使
`app` proxy 從未與其通訊，仍會保有 `backend.other` 的 cluster。

## 目標

使用 `Sidecar` 資源限制 `app` 命名空間的 proxies，使其只接收自身命名空間和
`istio-system` 的設定。

## 步驟 1. 觀察預設的（未限定範圍）設定

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config clusters "$POD" -n app | grep backend.other
# a cluster for backend.other.svc.cluster.local is present
```

## 步驟 2. 套用 Sidecar 資源以限制 egress 範圍

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Sidecar
metadata:
  name: default
  namespace: app
spec:
  egress:
    - hosts:
        - "./*"
        - "istio-system/*"
EOF
```

- `./*` - 本機命名空間（`app`）中的每個服務；
- `istio-system/*` - control-plane 命名空間（telemetry 等功能所需）。

名為 `default` 且沒有 `workloadSelector` 的 `Sidecar` 會套用至該命名空間中的所有
workloads。

## 步驟 3. 驗證設定已縮減

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')

# 'other' namespace clusters are gone
istioctl proxy-config clusters "$POD" -n app | grep backend.other || echo "pruned ✅"

# own namespace clusters remain
istioctl proxy-config clusters "$POD" -n app | grep ping-pong.app
```

## 運作方式與重要性

- **`Sidecar`** 資源控制 istiod 推送至 proxy 的設定範圍。`egress.hosts` 會將 proxy
  所知的服務加入白名單。
- 預設網格是「full mesh」：每個 proxy 都知道每個服務。在大型
  cluster（數千個服務）中，這代表龐大的 Envoy 設定、每個 pod 的高記憶體用量，以及每次變更時
  istiod 的繁重 CPU 負載。
- 使用 `Sidecar` 資源限制 proxies 範圍，是讓 Istio 擴展的標準方式：
  更小的設定、更快的推送、更低的 istiod 負載，以及更嚴格的 egress 邊界。
- `Sidecar` 內的 `outboundTrafficPolicy` 還可為每個命名空間設定 `REGISTRY_ONLY`，
  以封鎖未宣告的 egress。

> 注意：範圍限制涉及的是*設定散發*，而非授權。若要實際禁止
> 呼叫，請使用 `AuthorizationPolicy`（Lab 04）或 `outboundTrafficPolicy: REGISTRY_ONLY`。