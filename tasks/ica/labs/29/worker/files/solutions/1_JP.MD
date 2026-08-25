[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 29 - リファレンスソリューション

Istio `1.29.1` がインストールされています（ingress gateway の HTTPS は NodePort `32443` 上です）。PKI は
事前に作成されています:
- `myapp.local` 用の gateway サーバー証明書 + クライアント CA → secret `myapp-credential`
  （`istio-system`）;
- クライアント証明書バンドル → secret `client-certs`（`app`）;
- `passthrough.local` 用の TLS 証明書 → secret `backend-tls`（`backend`）。

ワークロード: `ping-pong`（namespace `app`、injected）および TLS 専用の `secure-backend`
（namespace `backend`、自身で TLS を終端し、`secure-ok` を返します）。

## 目標

port 443 の ingress gateway を、SNI によって選択される 2 つの TLS モードで設定します:
- `myapp.local` は **MUTUAL**: TLS を終端し、クライアント証明書を要求します（エッジでの mTLS）;
- `passthrough.local` は **PASSTHROUGH**: 暗号化されたストリームを backend に転送し、
  backend が TLS を終端します。

## ステップ 1. MUTUAL + PASSTHROUGH servers を持つ Gateway

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: edge-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 443
        name: https-mutual
        protocol: HTTPS
      tls:
        mode: MUTUAL
        credentialName: myapp-credential
      hosts:
        - "myapp.local"
    - port:
        number: 443
        name: https-passthrough
        protocol: HTTPS
      tls:
        mode: PASSTHROUGH
      hosts:
        - "passthrough.local"
EOF
```

## ステップ 2. MUTUAL host をルーティングする（終端後の HTTP）

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: myapp
  namespace: app
spec:
  hosts:
    - "myapp.local"
  gateways:
    - edge-gateway
  http:
    - route:
        - destination:
            host: ping-pong
            port:
              number: 8080
EOF
```

## ステップ 3. PASSTHROUGH host をルーティングする（SNI による TLS）

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: passthrough
  namespace: app
spec:
  hosts:
    - "passthrough.local"
  gateways:
    - edge-gateway
  tls:
    - match:
        - sniHosts:
            - "passthrough.local"
      route:
        - destination:
            host: secure-backend.backend.svc.cluster.local
            port:
              number: 443
EOF
```

## ステップ 4. 検証

```bash
# MUTUAL - without a client cert the handshake is rejected
curl -sk -o /dev/null -w "%{http_code}\n" https://myapp.local:32443/        # not 200

# MUTUAL - with the client cert it succeeds
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.crt}' | base64 -d > /tmp/c.crt
kubectl get secret client-certs -n app -o jsonpath='{.data.client\.key}' | base64 -d > /tmp/c.key
curl -sk --cert /tmp/c.crt --key /tmp/c.key https://myapp.local:32443/      # 200

# PASSTHROUGH - TLS terminates at the backend
curl -sk https://passthrough.local:32443/                                   # secure-ok
```

## TLS モードの概要

| モード | TLS を終端する対象 | クライアント証明書 | 典型的な用途 |
|---|---|---|---|
| `SIMPLE` (Lab 13) | gateway | なし | 標準的な HTTPS ingress |
| `MUTUAL` | gateway | **必須**（`ca.crt` に対して検証） | エッジでの mTLS、B2B/partner APIs |
| `PASSTHROUGH` | backend | gateway では n/a | エンドツーエンド暗号化、gateway が平文を確認できない/すべきではない場合 |
| `ISTIO_MUTUAL` | gateway (Istio certs) | Istio 管理 | mesh 内部の gateway トラフィック |

## 仕組み

- 単一の `Gateway` は **同じ port 上に複数の servers をホスト**できます。Istio は TLS **SNI**
  （`myapp.local` と `passthrough.local`）によって server を選択します。
- **MUTUAL**: gateway はサーバー証明書を提示してクライアント証明書を要求し、
  `myapp-credential` 内の `ca.crt` に対して検証します。終端後のルーティングは通常の
  L7（`http` route）です。
- **PASSTHROUGH**: gateway は復号せず、`VirtualService.tls` + `sniHosts` match を使用して L4 で
  SNI によってルーティングし、生の TLS を backend に転送します。backend が証明書を
  所有して TLS を終端します。