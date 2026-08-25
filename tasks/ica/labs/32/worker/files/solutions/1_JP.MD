[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 32 - リファレンスソリューション

Istio `1.29.1`（デフォルトプロファイル）がインストールされています。Namespace
`app`（istio-injection 有効）では、gRPC を使用する `viktoruj/ping_pong` イメージを
実行しています（`PingPong.Echo` は応答する pod のホスト名を返します）。

- **grpc-server** - gRPC Echo/Health サーバー、**3 レプリカ**（ポート `8079` 上の
  gRPC）。
- **grpc-client** - 同じイメージであり、gRPC 負荷の生成に使用されます
  （`/app -grpc-client ...`）。

`grpc-server` **Service** は、**誤った名前の**ポート（`tcp`）で作成されています。
そのため Istio はポート `8079` を生の L4 TCP として扱います。単一の長時間存続する
HTTP/2 gRPC 接続が 1 つの pod に固定されるため、クライアントが認識する個別のサーバーは
**1 つ**だけであり、リクエスト単位の負荷分散は行われません。

## 目標

1. Istio が gRPC ポートを認識するようにし、すべての backend pod 間で
   **リクエスト単位**（HTTP/2）の負荷分散を行えるようにします。
2. gRPC の**リトライ**と**タイムアウト**を備えた `grpc-server` 用の
   `VirtualService` を追加します。

## ステップ 1. Service ポート名を修正する

gRPC は生の TCP ではなく HTTP/2 です。Istio はポート名の**プレフィックス**
（`grpc`、`http2`、...）または明示的な `appProtocol` フィールドからプロトコルを
検出します。ポート名を `grpc` に変更します（および/または `appProtocol: grpc` を設定します）。

```bash
kubectl -n app patch svc grpc-server --type=json -p='[
  {"op":"replace","path":"/spec/ports/0/name","value":"grpc"},
  {"op":"add","path":"/spec/ports/0/appProtocol","value":"grpc"}
]'
```

同等の完全なマニフェスト:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  namespace: app
  labels:
    app: grpc-server
spec:
  selector:
    app: grpc-server
  ports:
    - name: grpc
      appProtocol: grpc
      port: 8079
      targetPort: 8079
EOF
```

Istio が HTTP/2（gRPC）クラスターを認識するとすぐに、Envoy は追加設定なしで、
共有接続内の**各リクエスト**をすべての endpoint 間で負荷分散します。

## ステップ 2. gRPC リトライ + タイムアウトを備えた VirtualService

gRPC は HTTP 上で動作するため、`tcp` ではなく `http` ブロックで設定します。
リトライ、タイムアウト、ヘッダールーティング、リクエスト単位の負荷分散がすべて適用されます。

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: grpc-server
  namespace: app
spec:
  hosts:
    - grpc-server
  http:
    - route:
        - destination:
            host: grpc-server
            port:
              number: 8079
      timeout: 2s
      retries:
        attempts: 3
        perTryTimeout: 1s
        retryOn: connect-failure,refused-stream,unavailable,cancelled,deadline-exceeded
EOF
```

- `retryOn` は gRPC 対応の条件を使用します。`unavailable`、`cancelled`、
  `deadline-exceeded` は gRPC ステータスコードに対応し、`refused-stream` と
  `connect-failure` はトランスポートの問題をカバーします。
- `timeout` はリクエスト全体を制限し、`perTryTimeout` は各試行を制限します。

## ステップ 3. （任意）負荷分散ポリシーを固定する

ポートが gRPC になると、リクエスト単位の負荷分散はデフォルトで有効になります。
ポリシーを明示的にするには、以下を実行します。

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: grpc-server
  namespace: app
spec:
  host: grpc-server
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
EOF
```

## ステップ 4. 検証

クライアントから gRPC 負荷を生成し、リクエストが**3 つすべての** backend pod に
到達することを確認します（リクエスト単位の負荷分散）。

```bash
kubectl exec -n app deploy/grpc-client -c ping-pong -- \
  /app -grpc-client -target grpc-server:8079 -n 180 -c 4
```

想定される末尾:

```
--- summary ---
requests: 180  ok: 180  errors: 0
distinct servers: 3
host grpc-server-xxxx-aaaa: 60
host grpc-server-xxxx-bbbb: 60
host grpc-server-xxxx-cccc: 60
```

`distinct servers: 3` は、リクエストがリクエスト単位で負荷分散されていることを示します。
修正前（ポート名が `tcp`）は、同じコマンドで `distinct servers: 1` と報告されます。

## これが機能する理由

- **gRPC は TCP ではなく HTTP/2 です。** L4/TCP として扱う場合、Envoy は
  *接続*を負荷分散します。1 つの gRPC クライアントは単一の長時間存続する接続を維持するため、
  すべての呼び出しが 1 つの pod に固定されます。ポートを `grpc` として宣言すると、Envoy は
  HTTP/2 を解析し、**各リクエスト**（ストリーム）を endpoint 間で負荷分散します。
- **ポート名が切り替えの鍵です。** ポート名は `grpc` / `grpc-*`（または `http2`）にするか、
  `appProtocol: grpc` を設定する必要があります。中立的な名前（`tcp`、名前なし）では、
  リクエスト単位の LB、リトライ、タイムアウト、gRPC メトリクスを含むすべての L7 機能が失われます。
- **L7 機能は gRPC に適用されます。** gRPC は HTTP であるため、gRPC 対応の `retryOn` を
  含む `http` リトライ、`timeout`/`perTryTimeout`、ヘッダールーティング、フォールトインジェクション、
  リッチなテレメトリーを受け取ります。これは通常の HTTP とまったく同じです。
