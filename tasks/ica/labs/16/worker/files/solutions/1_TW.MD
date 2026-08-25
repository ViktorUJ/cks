[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 16 - 參考解答

Istio `1.29.1` 已安裝（default 設定檔），且 Kubernetes Gateway API
CRD（`v1.2.1`）已存在。應用程式（`ping-pong-v1` / `ping-pong-v2`）已部署於
namespace `app`。

## 步驟 1. 部署應用程式

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/16/k8s-1/scripts/1.yaml
kubectl get pods -n app
```

每個 Pod 應為 `2/2`（應用程式 + istio-proxy sidecar）。

## 步驟 2. 建立 Gateway（Kubernetes Gateway API）

此 Gateway 已加上註解，使 Istio 為其佈建 **NodePort** Service（此測試
環境沒有雲端負載平衡器）。

```bash
cat > gateway.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web-gateway
  namespace: app
  annotations:
    networking.istio.io/service-type: NodePort
spec:
  gatewayClassName: istio
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
EOF

kubectl apply -f gateway.yaml
```

Istio 會在 `app` namespace 中自動佈建名為 `web-gateway-istio` 的 Deployment
與 Service：

```bash
kubectl get gateway web-gateway -n app
kubectl get deploy,svc web-gateway-istio -n app
```

## 步驟 3. 建立 HTTPRoute

將含有 `x-version: canary` 標頭的流量路由至 **v2**，其餘所有流量路由至 **v1**。

```bash
cat > httproute.yaml <<'EOF'
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ping-pong-route
  namespace: app
spec:
  parentRefs:
    - name: web-gateway
  rules:
    - matches:
        - headers:
            - name: x-version
              value: canary
      backendRefs:
        - name: ping-pong-v2
          port: 8080
    - backendRefs:
        - name: ping-pong-v1
          port: 8080
EOF

kubectl apply -f httproute.yaml
```

## 步驟 4. 驗證路由

```bash
NODEPORT=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# default -> v1
curl -s http://myapp.local:${NODEPORT}/

# canary header -> v2
curl -s -H "x-version: canary" http://myapp.local:${NODEPORT}/
```

預期結果：預設請求會回傳 `Ping-Pong-V1 (Stable)`，含有
`x-version: canary` 標頭的請求會回傳 `Ping-Pong-V2 (Canary)`。

## Istio API 與 Gateway API

| 概念 | Istio API | Kubernetes Gateway API |
|---|---|---|
| 入口點 | `Gateway` (networking.istio.io) | `Gateway` (gateway.networking.k8s.io) |
| 路由規則 | `VirtualService` | `HTTPRoute` |
| 後端 | `host` + `subset` (+ `DestinationRule`) | `backendRefs` |
| Gateway Pod | 共用的 `istio-ingressgateway` | 每個 `Gateway` 均會自動佈建 |
| 可攜性 | Istio 專用 | 供應商中立，可跨 mesh/ingress 使用 |
