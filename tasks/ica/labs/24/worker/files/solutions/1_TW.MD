[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 24 - 參考解答

Istio `1.29.1` 已以 **ambient** 模式安裝（istiod + istio-cni + ztunnel）。命名空間
`app` 已加入 ambient（`istio.io/dataplane-mode: ambient`），並執行
`ping-pong` 和 `app-client`，兩者皆**沒有** sidecar。工作電腦上可使用 `istioctl`。

## 背景

- **ztunnel** 為每個 ambient workload 提供 L4 mTLS 與身分識別，但它**不會**
  理解 HTTP。因此，L4 政策（依身分識別/連接埠允許或拒絕）可運作，但 L7 規則
  （HTTP 方法、路徑、標頭）則無法運作。
- 若要強制執行 **L7** 政策，請新增 **waypoint proxy**，這是一個以命名空間（或
  服務）為單位的 Envoy，ambient 流量會透過它進行路由以處理 L7。

## 目標

在 `app` 命名空間中新增 waypoint，並建立一個 L7 `AuthorizationPolicy`，僅允許對
`ping-pong` 的 `GET` 請求（其他所有請求 → `403`）。

## 步驟 1. 佈建 waypoint

```bash
istioctl waypoint apply -n app --enroll-namespace
kubectl get gtw waypoint -n app
kubectl rollout status deploy/waypoint -n app
```

`--enroll-namespace` 會為命名空間加上標籤（`istio.io/use-waypoint: waypoint`），因此前往
`app` 中服務的流量會經由 waypoint 路由。

## 步驟 2. 套用 L7 AuthorizationPolicy

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: allow-get-only
  namespace: app
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: waypoint
  action: ALLOW
  rules:
    - to:
        - operation:
            methods: ["GET"]
EOF
```

`ALLOW` 政策會預設拒絕所有不符合它的項目，因此只有 `GET` 能通過，其他方法會得到
`403`。

## 步驟 3. 驗證

```bash
# GET -> allowed
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X GET http://ping-pong.app.svc.cluster.local:8080/
# -> 200

# DELETE -> denied by the waypoint
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s -o /dev/null -w "%{http_code}\n" -X DELETE http://ping-pong.app.svc.cluster.local:8080/
# -> 403
```

## 運作方式

- **無 sidecar 的 L4（ztunnel）** 可在整個命名空間中處理 mTLS 與身分識別，不需要
  每個 pod 都有 proxy。它成本低，且在 ambient 中始終啟用。
- **Waypoint（L7）** 僅在需要 HTTP 層級功能時新增：L7 授權、路由、重試、流量分割。
  只有這些服務需要付出 Envoy 的成本。
- `AuthorizationPolicy` 的 `targetRefs` 指向 waypoint `Gateway`，因此會在
  L7 hop 強制執行。同一項附加至 sidecar/ingress 的政策也能運作，ambient 只是把
  L7 強制執行點移至 waypoint。
- 此分層模型（所有地方皆由 ztunnel 處理 L4，需要的地方由 waypoint 處理 L7）是 ambient 的
  核心概念：相較於 sidecar 有更低的基礎成本，並可選擇加入 L7。

## 相關內容

實驗 09 涵蓋 ambient 基礎（ztunnel L4）。實驗 04 涵蓋 sidecar 模型中相同的
`AuthorizationPolicy`。
