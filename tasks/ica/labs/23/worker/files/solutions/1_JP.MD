[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 23 - リファレンスソリューション

Istio `1.29.1` がインストールされています（ingress gateway は NodePort `32080` 上）。アプリ `ping-pong`
は名前空間 `app` にデプロイされ、`http://myapp.local:32080/` で公開されています。

## 目標

Envoy データプレーンを **WebAssembly** モジュールで拡張します。ingress gateway にコミュニティの
`basic_auth` Wasm 拡張機能をロードし、リクエストに HTTP Basic 認証を必須にします。

> Istio `1.29` は `WasmPlugin` API（`extensions.istio.io/v1alpha1`）を使用します。`1.30+` では
> これは `TrafficExtension` API に置き換えられています。

## ステップ 1. ベースライン（認証不要）

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## ステップ 2. WasmPlugin を適用する

```bash
kubectl apply -f - <<'EOF'
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: basic-auth
  namespace: istio-system
spec:
  selector:
    matchLabels:
      istio: ingressgateway
  phase: AUTHN
  url: oci://ghcr.io/istio-ecosystem/wasm-extensions/basic_auth:1.12.0
  pluginConfig:
    basic_auth_rules:
      - prefix: "/"
        request_methods:
          - "GET"
        credentials:
          - "ok:test"
          - "YWRtaW4zOmFkbWluMw=="
EOF
```

Ingress gateway 上の Istio エージェントが OCI Wasm イメージをダウンロードし、ローカルにキャッシュして、
HTTP フィルターとして注入します。数秒待ってください。

## ステップ 3. 検証

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## 仕組み

- **WebAssembly (Wasm)** では、プロキシを再ビルドすることなく Envoy にカスタムロジックを追加でき、
  実行時に動的にロードできます。
- **`url: oci://...`**: モジュールは OCI アーティファクトとして配布されます。Istio エージェントが取得して
  キャッシュします。`file://`（イメージに組み込み済み）または `http(s)://` も使用できます。
- **`phase: AUTHN`** はフィルターをチェーンの早い段階（ルーティング/認可の前）に配置します。
- **`selector`** はラベルによってワークロードにプラグインのスコープを設定します（ここでは ingress gateway）。
  gateway selector を含む `istio-system` の WasmPlugin は gateway のみに影響します。
- **`pluginConfig`** はモジュールに渡されます。`basic_auth` モジュールは
  `basic_auth_rules`（パスプレフィックス、メソッド、許可される認証情報）を読み取ります。

## Wasm を使用すべき場合

- Istio の組み込み CRD（`AuthorizationPolicy`、`EnvoyFilter`）では表現できないカスタム認証、ヘッダーの
  拡充、リクエスト検証、またはプロトコルロジック。
- まず組み込み API を優先し、データプレーンでカスタムコードが本当に必要な場合に Wasm を使用してください。
  運用コストに注意してください。モジュールの配布、バージョニング、実行時の取得（ダウンロード失敗時の動作は
  `failStrategy` が制御します）。
