[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 27 - 參考解答

已安裝 Istio `1.29.1`（ingress gateway 位於 NodePort `32080`）。應用程式 `ping-pong`
已部署於命名空間 `app`，並透過 `http://myapp.local:32080/` 對外公開。

## 目標

將帶有 **inline Lua** HTTP 篩選器的 `EnvoyFilter` 附加至 ingress gateway，使其：
- 新增回應標頭 `x-lua-lab: hello-from-lua`；
- 拒絕任何帶有 `x-block: yes` 的請求，並回傳 `403`。

## 步驟 1. 基準測試

```bash
curl -sI http://myapp.local:32080/ | grep -i x-lua-lab   # nothing yet
curl -s -o /dev/null -w "%{http_code}\n" -H "x-block: yes" http://myapp.local:32080/   # 200
```

## 步驟 2. 套用 Lua EnvoyFilter

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

## 步驟 3. 驗證

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

## 運作方式

- **`EnvoyFilter`** 會修補 Istio 產生的原始 Envoy 設定。此處將內建的 **Lua** HTTP 篩選器
  （`envoy.filters.http.lua`）插入 ingress gateway 的篩選器鏈中，位置就在 router 之前。
- Lua 指令碼實作兩個生命週期回呼：
  - `envoy_on_request(request_handle)`：每個請求都會執行；可讀取或修改標頭、讀取
    內容主體，或以 `request_handle:respond(...)` 提前中止並回應。
  - `envoy_on_response(response_handle)`：每個回應都會執行；此處會新增一個標頭。
- `context: GATEWAY` 將修補的範圍限制為 ingress gateway。若要改為指定工作負載 sidecar，請使用 `SIDECAR_INBOUND` /
  `SIDECAR_OUTBOUND`。

## Lua 與 Wasm 與內建 CRD

- **Inline Lua**：加入少量自訂邏輯最快的方式：無需映像檔、無需建置，可直接在 YAML 中編輯
  指令碼。適合調整標頭、簡單的請求閘控與快速實驗。
- **Wasm**（實驗 23）：適用於以真正程式語言（Rust/Go）撰寫的較重或可重用邏輯，會進行版本管理
  並以 OCI 映像檔發佈，在沙箱中執行。
- **內建 CRD**（`AuthorizationPolicy`、`Telemetry`、...）：應一律優先使用這些；
  僅在它們無法表達所需需求時才使用 Lua/Wasm。

> `EnvoyFilter` 是低階且對版本敏感的 API。Istio 警告其設定可能會在
> 版本之間變更。請將此類修補維持在最小範圍，並在升級時進行測試。