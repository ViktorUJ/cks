[Русская версия](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [日本語版](jp.md)

# 第 32 章。ICA 考試：格式與準備

> **最終章。** 在整個課程中，我們同時為 **Istio Certified Associate (ICA)**
> 認證準備了理論與實作。本章將彙整考試的形式、準備方式，以及在哪裡取得試跑機會--我們的
> mock 考試。

## 32.1. 這是什麼考試

**ICA (Istio Certified Associate)** 是 CNCF 與 Linux Foundation 提供的認證
(最初由 Tetrate 開發)，可證明您使用 Istio 的能力。考試為**線上且有監考**，其格式為
**混合式--實作型（performance-based）任務加上選擇題（multiple-choice）**。實作部分會提供您
叢集存取權，並要求您親手解決任務--設定路由、啟用 mTLS、撰寫策略、找出並修復問題；理論部分則
檢驗您對原則與術語的理解。考試時長為 **2 小時**，環境已更新至 **Istio
v1.26**。

考試期間允許存取官方文件（istio.io 及其子網域；通常也包括 Istio 部落格與 Kubernetes 文件--
請在 Candidate Handbook 查看最新的允許資源清單）。這很重要：沒有人要求您死記所有 YAML 欄位，
但您需要**快速**找到並套用所需內容。

> 確切細節（時長、及格分數、任務數量、重考規則）會隨時間變化，並取決於計畫版本。請務必查閱官方頁面：
> [Istio Certified Associate (ICA)](https://training.linuxfoundation.org/certification/istio-certified-associate-ica)。

## 32.2. 領域與應著重之處

考試依加權領域設計。目前的分配（2025 年 8 月計畫更新後）：

| 領域 | 比重 | 課程章節 |
|-------|-----|-------------|
| Traffic Management | 35% | 5-12 |
| Securing Workloads | 25% | 9, 13-16 |
| Installation, Upgrade & Configuration | 20% | 2-4, 22 (ambient) |
| Troubleshooting | 20% | 24, 30 |

關於新計畫的重要事項：

- **不再有獨立的「Advanced Scenarios」領域**--其主題已重新分配：ambient 安裝歸入 Installation，
  egress 與連接外部服務則歸入 Traffic Management。
- **Installation 提升至 20%**，現在明確包括以 **sidecar 和 ambient 模式**安裝、自訂與升級
  (canary/in-place)。
- **Traffic Management 包括 egress、ingress、韌性**（circuit breaking、failover、outlier detection、
  逾時、重試）**以及 fault injection**。
- **Securing Workloads**--授權、驗證（mTLS、JWT）以及以 TLS **保護 edge 流量**。
- **Troubleshooting**--設定、control plane 與 data plane。

結論：**最應加強流量管理**（Gateway、VirtualService、DestinationRule、路由、韌性、egress、
fault injection）--這是最大的領域（35%）。其後各項優先順序大致相當：安全性（25%）、安裝／升級與
troubleshooting（各 20%）--不要略過安裝與除錯，兩者的比重已顯著提高。

## 32.3. 實用建議

CKA/CKS 經驗可直接套用：

- **別名與自動補全。** 設定 `alias k=kubectl`，並為 `kubectl` 與 `istioctl` 啟用 completion--
  這能在每項任務節省時間。
- **檢查 context。** 請始終確認您正在操作哪個叢集與 namespace
  (`kubectl config current-context`)，尤其是在任務很多時。
- **逐字閱讀任務。** 資源名稱、namespace、連接埠、版本都必須精確--subset 名稱或 selector 的錯誤，
  都會使規則無法運作（第 5 章）。
- **驗證結果。** 設定後，從 Pod 執行 `curl`，查看狀態碼與標頭--確定流量確實流向正確位置。
- **`istioctl analyze` 是您的好幫手。** 它能快速偵測設定錯誤（第 24 章）。遇到問題時，使用
  `proxy-status`（SYNCED?）和 `proxy-config`。
- **時間管理。** 不要卡在單一任務上。略過困難的題目，稍後再回來--就像 CKA 一樣。
- **文件隨手可查。** 預先知道 istio.io 中 Gateway、VirtualService、PeerAuthentication 範例的位置--
  考試時您會從那裡複製並修改。

## 32.4. 模擬考試（mock）

最好的準備是計時完成逼真的考試。此儲存庫有**兩個 mock 考試**，用於模擬 ICA 格式：

- **Mock 01**--17 項基礎主題任務：安裝、Gateway/VirtualService、
  AuthorizationPolicy、注入管理。
  [tasks/ica/mock/01](../../mock/01/README.MD)
- **Mock 02**--16 項進階模式任務：使用 operator 進行 canary 升級、透過 Helm 安裝、egress gateway、
  port-level 負載平衡、fault injection、跨 namespace 授權。
  [tasks/ica/mock/02](../../mock/02/README.MD)

環境的一般說明、命令（`check_result`、`time_left`、`hosts`）與建議，請見基礎設施根目錄的 README：
[tasks/ica/README.MD](../../README_TW.MD)。

如何使用 mock：

1. 完成相關主題的章節與實驗。
2. **計時**完成 mock，如同真正的考試，不使用提示。
3. 透過 `check_result` 自我檢查，並依解答分析錯誤。
4. 重複進行，直到您能穩定地在時限內完成並取得 **70%+** 成績。

mock 訓練的是考試的**實作**部分。但請記住，考試格式是混合式的：也有檢驗對原則和術語理解的選擇題。
因此，除了 mock 外，也要依章節複習**理論**（每種資源的作用、mTLS、xDS、locality 負載平衡的運作方式）--
「我能親手操作」與「我理解原因」兩者都會受到檢驗。

## 32.5. 如何透過本課程準備

建議路線：

1. **第 1 部分（第 1-24 章）**--基礎與所有考試領域。以實驗（🧪）鞏固每一章。
2. **Mock**（第 32.4 節）--在第 1 部分之後計時完成。
3. **第 2 部分（第 25-31 章）**--實際工作的最佳實務。它們並非考試本身的必要內容，但能讓您成為理解
   生產環境中 Istio 的工程師，而不只是通過測驗的人。

## 32.6. 總結

- ICA 是有監考的線上考試，格式為**混合式**：在叢集上完成實作任務加上選擇題；允許存取 istio.io 文件，
  時長為 2 小時，環境為 v1.26。
- 目前領域（截至 2025 年 8 月）：**Traffic Management 35%**、Securing Workloads 25%、
  Installation/Upgrade/Config 20%、Troubleshooting 20%；不再有「Advanced Scenarios」領域。
- 最應加強流量管理，但不要略過安裝與 troubleshooting--它們的比重已提高至 20%。
- 套用 CKA/CKS 的習慣：別名、自動補全、檢查 context、逐字閱讀任務、驗證結果、時間管理。
- **計時**完成 **mock 01 與 mock 02** 以進行實作練習，並依章節複習理論（供 multiple-choice 部分使用）；
  目標是穩定取得 70%+。
- 請在 ICA 官方頁面查閱確切的安排與規則（及格分數、問題數量、允許資源）。

---

至此，本課程告一段落。您已從 service mesh 的概念一路學到 Istio 的生產環境運作：流量管理、韌性、安全性、
可觀測性、進階情境、troubleshooting、實際遷移、hardening，以及考試準備。可視需要回來查閱章節、實驗與 mock。
祝您 ICA 順利，也祝您在實戰中順利使用 Istio。

[目錄](../README_TW.md) · [第 31 章](../31/tw.md)
