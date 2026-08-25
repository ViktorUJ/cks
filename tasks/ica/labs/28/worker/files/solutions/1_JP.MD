[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 28 - リファレンスソリューション

Istio `1.29.1` は、ingress gateway 上で固定 TCP NodePort `31400` を使用してインストールされています。アプリ
`tcp-echo` は namespace `app` に 2 つのバージョンでデプロイされています。
- **v1** は `one` プレフィックスで応答します。
- **v2** は `two` プレフィックスで応答します。

どちらも生の TCP port `9000` でリッスンします（HTTP ではありません）。

## 目標

TCP listener を持つ `Gateway` と、v1 と v2 の間で重み付けされた `tcp` route を持つ `VirtualService` を使用して、ingress gateway 経由で生の **TCP** service をルーティングします。

## ステップ 1. TCP listener を持つ Gateway

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: tcp-echo-gateway
  namespace: app
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 31400
        name: tcp
        protocol: TCP
      hosts:
        - "*"
EOF
```

## ステップ 2. subset を持つ DestinationRule

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: tcp-echo
  namespace: app
spec:
  host: tcp-echo
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
EOF
```

## ステップ 3. TCP route を持つ VirtualService

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: tcp-echo
  namespace: app
spec:
  hosts:
    - "*"
  gateways:
    - tcp-echo-gateway
  tcp:
    - match:
        - port: 31400
      route:
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v1
          weight: 80
        - destination:
            host: tcp-echo
            port:
              number: 9000
            subset: v2
          weight: 20
EOF
```

## ステップ 4. 検証

```bash
for i in $(seq 10); do
  echo "hello" | timeout 3 bash -c 'exec 3<>/dev/tcp/myapp.local/31400; cat >&3; head -n 1 <&3'
done
# ~80% "one hello", ~20% "two hello"
```

（`nc` がインストールされている場合: `echo hello | nc myapp.local 31400`。）

## 仕組み

- **TCP routing** は Layer 4 で動作します。HTTP host/path/header がないため、**listener port** (`match.port`) に基づいてルーティングされます。`protocol: TCP` を持つ `Gateway` server により、Envoy はプレーン TCP listener を開きます。`VirtualService.tcp` route は接続を選択された backend subset に転送します。
- **Port naming**: service/gateway port の名前は `tcp`（または `tcp-*`）でなければなりません。Istio は port name prefix を使用して protocol を検出します。prefix なし、または `http-*` の名前では、Istio はこれを HTTP として扱い、生の protocol は壊れます。
- **Weighted TCP** は subset 間で *connections*（requests ではありません）を分割します。新しい各 TCP connection は重みによってルーティングされます。
- L7 features（retries、header routing、fault injection）は TCP routes には**適用されません**。`DestinationRule` 経由の connection-level policies（connection pool、timeouts）のみが適用されます。

## 関連するプロトコル

- **MongoDB/MySQL/Redis** - Envoy が適切な protocol parser を適用するよう、port に `mongo-*` / `mysql-*` / `redis-*` という名前を付けます。routing は引き続き `tcp` routes を使用します。
- **WebSocket** - long-lived であるにもかかわらず HTTP `Upgrade` 上で動作するため、TCP ではなく通常の `http` routes と `http-*` port names を使用してください。
