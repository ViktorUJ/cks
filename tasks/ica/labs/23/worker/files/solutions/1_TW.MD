[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 23 - 參考解答

已安裝 Istio `1.29.1`（ingress gateway 使用 NodePort `32080`）。應用程式 `ping-pong`
部署在命名空間 `app` 中，並透過 `http://myapp.local:32080/` 公開。

## 目標

使用 **WebAssembly** 模組擴充 Envoy 資料平面：在 ingress gateway 上載入社群
`basic_auth` Wasm 擴充功能，使請求需要 HTTP Basic 驗證。

> Istio `1.29` 使用 `WasmPlugin` API（`extensions.istio.io/v1alpha1`）。在 `1.30+` 中，
> 它正由 `TrafficExtension` API 取代。

## 步驟 1. 基準線（不需要驗證）

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## 步驟 2. 套用 WasmPlugin

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

ingress gateway 上的 Istio agent 會下載 OCI Wasm 映像檔、在本機快取，
並將其注入為 HTTP filter。請稍候幾秒鐘。

## 步驟 3. 驗證

```bash
# no credentials -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# valid credentials -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## 運作方式

- **WebAssembly (Wasm)** 可讓您在不重新建置 proxy 的情況下，將自訂邏輯加入 Envoy，
  並在執行階段動態載入。
- **`url: oci://...`** - 模組以 OCI artifact 形式發布；Istio agent 會拉取並
  快取它。您也可以使用 `file://`（內建於映像檔）或 `http(s)://`。
- **`phase: AUTHN`** 會將 filter 放在鏈結的前段（位於 routing/authz 之前）。
- **`selector`** 依 labels 將 plugin 限定於 workloads（此處為 ingress gateway）。位於
  `istio-system` 且具備 gateway selector 的 WasmPlugin 僅會影響 gateway。
- **`pluginConfig`** 會傳遞給模組。`basic_auth` 模組會讀取
  `basic_auth_rules`（路徑 prefix、methods，以及接受的 credentials）。

## 何時應使用 Wasm

- 適用於 Istio 的內建 CRDs（`AuthorizationPolicy`、`EnvoyFilter`）無法表達的自訂
  驗證、header/enrichment、請求驗證或 protocol 邏輯。
- 優先使用內建 API；僅在資料平面確實需要自訂程式碼時使用 Wasm。請留意營運成本：模組
  發布、版本控制，以及執行階段 fetch（若下載失敗，`failStrategy` 會控制行為）。