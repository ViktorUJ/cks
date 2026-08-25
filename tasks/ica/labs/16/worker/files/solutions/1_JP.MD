[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 16 - 参照解答

Istio `1.29.1` はすでにインストール済みです（デフォルトプロファイル）。Kubernetes Gateway API
CRD（`v1.2.1`）も存在します。アプリ（`ping-pong-v1` / `ping-pong-v2`）は
namespace `app` にデプロイされています。

## ステップ 1. アプリケーションをデプロイする

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/16/k8s-1/scripts/1.yaml
kubectl get pods -n app
```

各 Pod は `2/2`（app + istio-proxy サイドカー）である必要があります。

## ステップ 2. Gateway を作成する（Kubernetes Gateway API）

Gateway にはアノテーションが付与されているため、Istio はこれ用の **NodePort** Service をプロビジョニングします（このテスト環境にはクラウドロードバランサーがありません）。

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

Istio は `app` namespace 内に、`web-gateway-istio` という名前の Deployment と Service を自動的にプロビジョニングします。

```bash
kubectl get gateway web-gateway -n app
kubectl get deploy,svc web-gateway-istio -n app
```

## ステップ 3. HTTPRoute を作成する

`x-version: canary` ヘッダーを **v2** にルーティングし、それ以外はすべて **v1** にルーティングします。

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

## ステップ 4. ルーティングを検証する

```bash
NODEPORT=$(kubectl get svc web-gateway-istio -n app -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')

# default -> v1
curl -s http://myapp.local:${NODEPORT}/

# canary header -> v2
curl -s -H "x-version: canary" http://myapp.local:${NODEPORT}/
```

想定結果: デフォルトのリクエストは `Ping-Pong-V1 (Stable)` を返し、`x-version: canary` ヘッダー付きのリクエストは `Ping-Pong-V2 (Canary)` を返します。

## Istio API と Gateway API

| 概念 | Istio API | Kubernetes Gateway API |
|---|---|---|
| エントリポイント | `Gateway` (networking.istio.io) | `Gateway` (gateway.networking.k8s.io) |
| ルーティングルール | `VirtualService` | `HTTPRoute` |
| バックエンド | `host` + `subset` (+ `DestinationRule`) | `backendRefs` |
| Gateway Pod | 共有の `istio-ingressgateway` | `Gateway` ごとに自動プロビジョニング |
| 可搬性 | Istio 固有 | ベンダー中立で、メッシュおよび Ingress 間でポータブル |