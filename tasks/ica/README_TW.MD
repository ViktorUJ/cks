[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Istio Certified Associate (ICA) - 培訓教材

<img src="../../docs/images/ICA.png" alt="Istio Certified Associate" width="200">

**Istio Certified Associate (ICA)** 認證的完整準備：自學課程、實作實驗以及完整的模擬
考試 - 全部集中在一處。

## 內容概覽

| 部分 | 路徑 | 說明 |
|-------|------|-----------|
| **課程** | [`course/`](course/README_TW.md) | 32 章的自學課程：從 service mesh 的概念到生產環境營運 |
| **實驗** | [`labs/`](labs/) | 在真實 AWS 叢集上的 35 個實作實驗，每個都對應課程章節 |
| **模擬考試** | [`mock/`](mock/) | 2 個完整的模擬考試，重現真實的 ICA 體驗 |

建議路線：學習課程章節，用對應的實驗鞏固，然後在時間限制下完成模擬考試。

## 課程

課程 ([`course/README_TW.md`](course/README_TW.md)) 共 32 章，專為已經熟悉 Kubernetes
（CKA 等級）的工程師撰寫：

- **第 1 部分（第 1-24 章）** - 基礎與 ICA 考試領域的完整涵蓋（流量管理、安全性、
  observability、進階場景、troubleshooting、安裝）。
- **第 2 部分（第 25-31 章）** - 實際營運的 best practices：漸進式交付、零停機遷移、
  EKS 上的 Istio、多叢集、VM 工作負載、control plane 效能、加固。
- **考試準備（第 32 章）** - ICA 格式、技巧以及模擬考試的連結。

每一章都以 **「實作」** 區塊結尾，連結到對應的實驗。

## 實驗

35 個實作實驗（`labs/01` .. `labs/35`），每個都完整在地化為 8 種語言：英文
（`README.MD`）、俄文（`README_RU.MD`）、西班牙文（`README_ES.MD`）、法文
（`README_FR.MD`）、德文（`README_DE.MD`）、喬治亞文（`README_GE.MD`）、繁體中文
（`README_TW.MD`）與日文（`README_JP.MD`）。它們透過 Terragrunt 在 AWS 上部署真實叢集：

```bash
TASK=01 make run_ica_task      # 部署實驗 01
TASK=01 make delete_ica_task   # 刪除
```

實驗主題（以及涵蓋理論的課程章節）：

| 實驗 | 主題 | 章節 |
|------|------|------|
| 01 | 安裝 Istio、Bookinfo、sidecar injection | 2 |
| 02 | Dark launch、header-routing、canary | 5, 6 |
| 03 | Fault injection 與 retries | 8 |
| 04 | mTLS (PeerAuthentication) + AuthorizationPolicy | 13, 14 |
| 05 | Egress：ServiceEntry、egress gateway、REGISTRY_ONLY | 12 |
| 06 | 負載平衡 + 流量 mirroring | 6, 7 |
| 07 | 使用 Helm 安裝 + canary 升級（修訂版） | 3 |
| 08 | Observability：Prometheus/Jaeger/Kiali | 17 |
| 09 | Ambient mode（無 sidecar） | 22 |
| 10 | 韌性：timeout + circuit breaker | 8 |
| 11 | 終端使用者驗證：RequestAuthentication + JWT | 15 |
| 12 | 使用 istioctl 進行 Troubleshooting | 24 |
| 13 | Edge TLS (SIMPLE) | 9 |
| 14 | Locality-aware failover | 7 |
| 15 | 安裝與設定 (IstioOperator + MeshConfig) | 2 |
| 16 | Kubernetes Gateway API (Gateway + HTTPRoute) | 11 |
| 17 | 本地 rate limiting (EnvoyFilter) | 20 |
| 18 | Telemetry API：access logs + tracing | 18 |
| 19 | istiod 中的自訂 CA | 16 |
| 20 | mTLS 遷移 PERMISSIVE → STRICT | 13 |
| 21 | Sidecar scoping | 19 |
| 22 | TLS origination | 12 |
| 23 | WasmPlugin (WebAssembly) | 21 |
| 24 | Ambient：waypoint proxy + L7 授權 | 22 |
| 25 | 使用 Flagger 的漸進式交付 | 25 |
| 26 | 動態 CA：cert-manager + istio-csr | 16 |
| 27 | EnvoyFilter + Lua | 21 |
| 28 | TCP 路由 | 10 |
| 29 | Ingress TLS：MUTUAL 與 PASSTHROUGH | 9 |
| 30 | StatefulSet 與 headless 服務 | 23 |
| 31 | 零停機遷移：ingress-nginx → Istio | 26 |
| 32 | gRPC：per-request 負載平衡、連接埠命名、retries | 10 |
| 33 | Control plane：效能與營運 | 30 |
| 34 | 加固與威脅模型 | 31 |
| 35 | 多叢集 mesh (multi-primary, multi-network) | 28 |

## 模擬考試（mock）

兩個重現 ICA 格式的完整模擬考試：

- **Mock 01** ([`mock/01`](mock/01/README.MD)) - 關於 Istio 核心概念的 17 個任務。
- **Mock 02** ([`mock/02`](mock/02/README.MD)) - 關於進階 mesh 模式的 16 個任務。

在時間限制下、不使用提示地完成，並以 **70%+** 為目標。

## 自訂終端環境

![Terminal Interface](../../docs/images/cockpit.png)

基礎架構提供一個預先設定好的終端，內含專為 ICA 練習打造的工具與輔助程式。

### 可用指令
- **`time_left`** - 查看剩餘時間
- **`check_result`** - 驗證任務完成情況（`check_result <task>` 用於特定任務）
- **`hosts`** - 顯示 ingress gateway 資訊（NodePort 對應與 IP）

### 預先設定的工具（含 bash 補全）
- **`kubectl | k`**、**`istioctl`**、**`helm`**、**`yq`**、**`curl`/`wget`**、
  **`podman`**、**`aws`**

### SSH 存取
```bash
ssh <kubernetes_nodename>
```

## 快速開始

```bash
# 檢查你的分數（所有任務或特定任務）
check_result
check_result <task_number>

# 用於測試外部存取的叢集/ingress 資訊
hosts

# 計時執行期間的剩餘時間
time_left
```

## 考試期間允許的資源

你可以參考 Istio 官方文件：
**https://istio.io/latest/docs/** 及其所有子網域。模擬考試重現了這一點。

## 成功技巧

1. **仔細閱讀任務要求** - 精確的名稱、namespace 與 spec 都很重要。
2. **確認你的 context** - 使用 `kubectl config current-context`。
3. **測試你的工作** - 從 sleep pod 執行 `curl` 以檢查路由與政策。
4. **使用 `istioctl analyze`、`proxy-status`、`proxy-config`** - 找出設定錯誤。
5. **檢視參考解答** - 在嘗試任務之後。

## 常見陷阱

- **VirtualService 中的 hosts**：跨 namespace 流量請同時包含短名稱與 FQDN。
- **Gateway 選擇器**：必須與實際的 ingress gateway 標籤相符。
- **Sidecar injection**：pod 應顯示 `2/2` 容器。
- **切換 context**：套用資源前請再次確認叢集。

---

**祝你 ICA 認證順利！** 熟能生巧 - 完成課程、實驗與兩個模擬考試，直到你能在時間限制內
自信地完成任務。
