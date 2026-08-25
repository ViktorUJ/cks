[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 23 - WasmPlugin：透過 WebAssembly 擴充 data plane

> [參考解答](worker/files/solutions/1_TW.MD)

## 概覽

有時 Istio 內建的 CRD（`AuthorizationPolicy`、`EnvoyFilter`）並不足夠--需要直接在 data plane 中加入自訂邏輯。為此可使用 **WebAssembly (Wasm)**：您可自行撰寫（或採用現成）模組，而 Envoy 可在執行階段動態載入它，無須重新建置 proxy。

在本實驗中，您將在 ingress gateway 上連接社群模組 **`basic_auth`**，讓請求必須通過 HTTP Basic 驗證。

> Istio `1.29` 使用 `WasmPlugin` API（`extensions.istio.io/v1alpha1`）。在 `1.30+` 中，它將由 `TrafficExtension` API 取代。

Istio 已安裝（ingress gateway 使用 NodePort `32080`），`ping-pong` 應用程式已部署在 `app` namespace，並發布於 `http://myapp.local:32080/`。

```mermaid
flowchart LR
    C["client"] --> GW["istio-ingressgateway<br>+ WasmPlugin basic_auth"]
    GW -->|"沒有/錯誤 creds"| R["401 Unauthorized"]
    GW -->|"正確 creds"| A["ping-pong<br>200 OK"]
    OCI["oci://ghcr.io/.../basic_auth:1.12.0"] -.pull.-> GW
```

## 基礎設施

| 元件 | 類型 | 數量 | 角色 |
|---|---|---|---|
| control-plane | `t3.medium` | 1 | master + istiod + ingress gateway |
| worker | `t3.small` | 1 | 應用程式容量 |
| worker PC | `t3.small` | 1 | 工作站：`kubectl`、`curl`、`check_result` |

區域：`eu-central-1`（AZ `eu-central-1a` / `eu-central-1b`）。

## 部署

```bash
TASK=23 make run_ica_task
```

## 什麼是 WebAssembly（適合未接觸過的人）

簡單來說，**WebAssembly (Wasm)** 是一種小型編譯程式的格式，可在另一個程式內安全執行。Wasm 最初是為瀏覽器設計的（用來讓 C++/Rust 程式碼與 JavaScript 一同執行），但目前已被廣泛應用，包括在網路 proxy 內部。

以下逐步說明這裡發生的事：

- **什麼是 data plane 與 Envoy。** 在 Istio 中，每個 pod 旁都運行一個 **Envoy** proxy（也就是所謂的「sidecar」）。pod 的所有網路流量--進站和出站--都會經過它。這些 proxy 的整體稱為 *data plane*。真正套用規則的是 Envoy：mTLS、路由、限制、授權。
- **問題。** Envoy 原生功能很多，但無法預先涵蓋一切。過去若要加入自己的邏輯，必須以 C++ 重新建置 Envoy 並替換 proxy 映像，這既耗時、風險高，又容易在升級時失效。
- **Wasm plugin 的概念。** 不必重新建置，您可用方便的語言撰寫小模組（**Rust、C++、Go/TinyGo、AssemblyScript**），將它編譯成 `.wasm`，再「餵給」Envoy。Envoy 會**即時載入，無須重新啟動或重新建置**該模組，並開始讓請求通過它。
- **沙箱（sandbox）。** Wasm 模組在隔離環境中執行：它無法直接存取 Envoy 或主機的記憶體，且只能透過嚴格定義的介面與 proxy 溝通。即使模組「崩潰」，也不會使 proxy 一同崩潰。這讓在 proxy 中執行他人或自己的程式碼相對安全。
- **proxy-wasm ABI。** 「Envoy ↔ Wasm 模組」之間的互動由 **proxy-wasm** 協定標準化（函式 hook 的集合：「請求到達」、「標頭到達」、「主體到達」等）。由於共用這項標準，同一個模組可在不同 Envoy/Istio 版本中運作，甚至也能在其他支援 proxy-wasm 的 proxy 中運作。
- **模組如何進入 proxy。** 模組會封裝為 **OCI 映像**（如一般 Docker 映像）並放入 registry。在 `WasmPlugin` 中指定 `url: oci://...`，istio-agent 便會自行下載模組、在 node 上快取它，並將其作為 HTTP filter 連接至 Envoy。

類比來說，這就像「瀏覽器 plugin/extension」，只是這裡的 plugin 並非安裝在瀏覽器，而是安裝於網路 proxy；它處理的不是網頁，而是服務之間的網路請求。在本實驗中，這個「plugin」會是現成的 `basic_auth` 模組，在進入 mesh 時要求使用者名稱/密碼（HTTP Basic auth）。

## 現成模組與如何建立自己的模組

**現成 Wasm 模組（無須撰寫程式碼）。** 所需功能通常已由他人實作--只需在 `WasmPlugin` 中指定映像連結：

- **istio-ecosystem/wasm-extensions**--Istio 社群的官方範例（包括 `basic_auth` 等），發布於 `ghcr.io/istio-ecosystem/wasm-extensions/...`（本實驗正是使用它）。
- 廠商提供的**現成產品模組**（例如作為 Wasm 的 coraza-WAF、OPA、各種 auth/rate-limit filter），以 OCI 映像方式發布。
- **WebAssembly Hub / OCI registry**--模組封裝方式與一般 OCI 映像相同，因此可以儲存在任何 registry（ghcr、Docker Hub、ECR、私有 Harbor）。

規則很簡單：如果模組以 OCI 映像形式存在--您只要寫上 `url: oci://...`，不需要撰寫程式碼。

**若需要自訂模組--快速路徑。** 自訂邏輯以可編譯成 Wasm 的語言搭配 proxy-wasm SDK 撰寫：

1. **選擇語言和 SDK。** 常見選擇包括：**Rust**（`proxy-wasm/proxy-wasm-rust-sdk`）、**Go/TinyGo**（`proxy-wasm-go-sdk`）、C++ 或 AssemblyScript。正式環境多選 Rust（快速、`.wasm` 精簡）。
2. **撰寫 hook。** 在 SDK 中，您實作請求生命週期的 callback，例如 `on_http_request_headers`（收到請求標頭）、`on_http_response_headers` 等。內部放入您的邏輯：檢查標頭、加入/修改標頭、傳回錯誤。
3. **編譯為 Wasm。** 例如 Rust：
   ```bash
   rustup target add wasm32-wasip1
   cargo build --release --target wasm32-wasip1
   # 結果：target/wasm32-wasip1/release/my_plugin.wasm
   ```
4. **封裝成 OCI 映像並推送。** Istio 預期 Wasm 位於 OCI artifact 內。可使用如 `buildah`/`docker` 或 `func-e`/`wasme` 的工具建置；接著執行 `docker push <registry>/my-plugin:1.0`。
5. **透過 WasmPlugin 連接。** 指定 `url: oci://<registry>/my-plugin:1.0`，並在必要時以 `pluginConfig` 傳入自己的參數--與本實驗的方式相同。

以 Rust 撰寫的最小邏輯範例（加入回應標頭）：

```rust
use proxy_wasm::traits::*;
use proxy_wasm::types::*;

proxy_wasm::main! {{
    proxy_wasm::set_http_context(|_, _| -> Box<dyn HttpContext> { Box::new(MyPlugin) });
}}

struct MyPlugin;
impl Context for MyPlugin {}
impl HttpContext for MyPlugin {
    fn on_http_response_headers(&mut self, _n: usize, _eos: bool) -> Action {
        self.set_http_response_header("x-my-plugin", Some("hello"));
        Action::Continue
    }
}
```

若要進行實際開發，請參閱 `istio-ecosystem/wasm-extensions` repository 中的指南（如何撰寫、測試及建置 OCI 映像）。

## 任務

1. 驗證未安裝 plugin 時應用程式可存取（`200`）。
2. 套用 `WasmPlugin`，它會在 ingress gateway（`selector: istio=ingressgateway`）上從 OCI registry 載入 `basic_auth` 模組，並要求 Basic 驗證。
3. 驗證未提供認證資訊的請求會收到 `401`，而使用正確認證資訊時會收到 `200`。

## 步驟 1：基準行為（未使用 auth）

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/
# -> 200
```

## 步驟 2：套用 WasmPlugin

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

Ingress gateway 上的 istio-agent 會下載 Wasm OCI 映像、在本機快取它並將其嵌入為 HTTP filter。請等待幾秒鐘。

## 步驟 3：驗證

```bash
# 沒有憑證 -> 401
curl -s -o /dev/null -w "%{http_code}\n" http://myapp.local:32080/

# 帶有正確憑證 -> 200  (base64 of admin3:admin3)
curl -s -o /dev/null -w "%{http_code}\n" \
  -H "Authorization: Basic YWRtaW4zOmFkbWluMw==" http://myapp.local:32080/
```

## 運作原理

- **WebAssembly (Wasm)** 可在不重新建置 proxy 的情況下，將自訂邏輯新增至 Envoy，並在執行階段動態載入。
- **`url: oci://...`**--模組以 OCI artifact 提供；istio-agent 會拉取並快取它。同樣也支援 `file://`（內嵌於映像中）和 `http(s)://`。
- **`phase: AUTHN`** 會將 filter 置於鏈路早期（在路由/授權之前）。
- **`selector`** 依 label 將 plugin 限定至 workloads（此處為 ingress gateway）。
- **`pluginConfig`** 會傳入模組；`basic_auth` 讀取 `basic_auth_rules`（路徑 prefix、方法、允許的 creds）。

## 何時有用（實際情境）

- **自訂驗證/授權**：Basic auth、API key 驗證、請求 HMAC 簽章、與非標準 IdP 整合--無法透過 `RequestAuthentication`/`AuthorizationPolicy` 表達的需求。
- **請求/回應操作**：從外部來源擴充標頭、計算簽章、編輯主體（遮罩 PII）、標準化路徑。
- **邊界的協定和業務邏輯**：按自訂 key 的特定 rate limiting、feature flags、基於複雜規則的 A/B、解碼專有協定。
- **合規與安全性**：特殊格式的 audit logging、類似 WAF 的檢查、依自訂簽章封鎖。
- **將邏輯移出應用程式**：將相同的 cross-cutting 邏輯（auth、logging、headers）在 mesh 中實作一次，而非在每種語言的每個服務中重複實作。

## 相較於替代方案的優勢

| 方法 | 優點 | 缺點 / 何時不如 Wasm |
|---|---|---|
| **內建 CRD**（`AuthorizationPolicy`、`RequestAuthentication`、`Telemetry`、`EnvoyFilter` local ratelimit） | 簡單、宣告式、受 Istio 支援 | 受預先定義的功能限制；無法表達任意邏輯 |
| **`EnvoyFilter` + Lua**（參見 lua-scripts） | 無須重新建置，script 可直接內嵌 | 僅限 Lua；繁重任務較慢；沒有嚴格型別/測試；邏輯分散於 YAML |
| **使用原生 C++ filter 的 `EnvoyFilter`** | 最高速度 | 需要重新建置 Envoy 和自訂 proxy 映像；與升級不相容；門檻高 |
| **應用程式本身的邏輯** | 完全控制 | 在每種語言的每個服務中重複；難以確保一致性和更新 |
| **外部服務（ext_authz / callout）** | 可用任何語言、獨立部署 | 每個請求都多一次網路 hop 和延遲；營運中多一個元件 |
| **WasmPlugin（本實驗）** | 可使用任何可編譯成 Wasm 的語言撰寫自訂程式碼（C++、Rust、Go/TinyGo、AssemblyScript）；**在執行階段載入，無須重新建置 Envoy 或重啟**；以 **in-process** 執行（不像 ext_authz 沒有網路 hop）；Wasm 沙箱提供隔離與安全性；透過穩定的 proxy-wasm ABI 在 Envoy/Istio 版本間具可攜性；可經 OCI registry 進行版本控制與交付 | API 為 Alpha 狀態；執行階段載入和快取模組有額外負擔；自訂程式碼必須維護、測試和版本控制；除錯比宣告式 CRD 更困難 |

**簡而言之：**當 data plane 需要*任意*邏輯，同時又重視低延遲（in-process，沒有如 ext_authz 的額外 hop）、安全性（沙箱），以及可在不重新建置 proxy 的情況下動態推出/更新 filter 時，Wasm 就有優勢。

**實務上的選擇順序：**先使用內建 CRD → 若不足則使用 `EnvoyFilter`（簡單需求可使用 Lua）→ 若邏輯較適合由獨立服務承載且延遲不關鍵，則使用外部 `ext_authz` → 當需要在 proxy 本身執行快速的自訂 in-process 程式碼時，使用 **Wasm**。請考量 Wasm 的營運成本：模組交付、版本控制和執行階段載入（`failStrategy` 定義載入失敗時的行為--fail-open 或 fail-close）。

## 驗證結果

在 worker PC 上執行：

```bash
check_result
```

## 總結

您已使用從 OCI registry 載入的自訂 Wasm 模組擴充 data plane，並在 mesh 邊界新增 Basic 驗證，無須變更應用程式。使用 `WasmPlugin` 是當 Istio 內建功能不足時所需的 senior 技能。
