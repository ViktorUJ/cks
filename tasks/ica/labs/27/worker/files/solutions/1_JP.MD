[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 27 - リファレンスソリューション

Istio `1.29.1` がインストールされています（ingress gateway は NodePort `32080` 上）。アプリ `ping-pong`
は名前空間 `app` にデプロイされ、`http://myapp.local:32080/` で公開されています。

## 目的

ingress gateway に **インライン Lua** HTTP フィルターを持つ `EnvoyFilter` をアタッチし、次を実現します。
- レスポンスヘッダー `x-lua-lab: hello-from-lua` を追加する。
- `x-block: yes` を含むリクエストを `403` で拒否する。

## ステップ 1. ベースライン

```bash
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab   # nothing yet
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/   # 200
```

## ステップ 2. Lua EnvoyFilter を適用する

```bash
kubectl apply -f - <<'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: lua-edge
  namespace: istio-system
spec:
  workloadSelector:
    labels:
      istio: ingressgateway
  configPatches:
    - applyTo: HTTP_FILTER
      match:
        context: GATEWAY
        listener:
          filterChain:
            filter:
              name: envoy.filters.network.http_connection_manager
              subFilter:
                name: envoy.filters.http.router
      patch:
        operation: INSERT_BEFORE
        value:
          name: envoy.filters.http.lua
          typed_config:
            "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
            inlineCode: |
              function envoy_on_request(request_handle)
                if request_handle:headers():get("x-block") == "yes" then
                  request_handle:respond(
                    {[":status"] = "403"},
                    "blocked by lua\n")
                end
              end
              function envoy_on_response(response_handle)
                response_handle:headers():add("x-lua-lab", "hello-from-lua")
              end
EOF
```

## ステップ 3. 検証

```bash
# response header added by Lua
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab
# x-lua-lab: hello-from-lua

# request blocked by Lua
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/
# 403

# normal request still works
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# 200
```

## 仕組み

- **`EnvoyFilter`** は Istio が生成する生の Envoy 設定をパッチします。ここでは、組み込みの **Lua** HTTP フィルター（`envoy.filters.http.lua`）を ingress gateway のフィルターチェーンに、router の直前で挿入します。
- Lua スクリプトは 2 つのライフサイクルコールバックを実装します。
  - `envoy_on_request(request_handle)` はリクエストごとに実行されます。ヘッダーの読み取り・変更、body の読み取り、または `request_handle:respond(...)` による即時応答が可能です。
  - `envoy_on_response(response_handle)` はレスポンスごとに実行されます。ここではヘッダーを追加します。
- `context: GATEWAY` はパッチの対象を ingress gateway に限定します。代わりにワークロード sidecar を対象にするには `SIDECAR_INBOUND` / `SIDECAR_OUTBOUND` を使用します。

## Lua、Wasm、組み込み CRD の比較

- **インライン Lua** は、小規模なカスタムロジックを追加する最も手早い方法です。イメージもビルドも不要で、YAML 内のスクリプトを編集できます。ヘッダーの調整、シンプルなリクエストゲーティング、迅速な実験に適しています。
- **Wasm**（Lab 23）は、実際の言語（Rust/Go）で書く、より大規模で再利用可能なロジック向けです。OCI イメージとしてバージョン管理・配布され、sandbox 内で実行されます。
- **組み込み CRD**（`AuthorizationPolicy`、`Telemetry`、...）は、常に最初にこちらを優先してください。必要な表現ができない場合にのみ Lua/Wasm を使用します。

> `EnvoyFilter` は低レベルでバージョンに依存する API です。Istio は、その設定がリリース間で変更される可能性があると警告しています。このようなパッチは最小限に保ち、
> アップグレードをまたいでテストしてください。