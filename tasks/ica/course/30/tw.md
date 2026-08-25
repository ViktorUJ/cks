[Русская версия](ru.md) · [Eng version](en.md) · [Versión en español](es.md) · [Version française](fr.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [日本語版](jp.md)

# 第 30 章。control plane 的效能與營運

> **接下來。** 我們已從基礎一路學到多叢集與 VM。本章將完成營運部分：control plane 的運作方式、影響其效能的因素、應監控的項目、如何調校，以及如何在生產環境中維持 mesh 的健康。接下來還有兩章--強化防護與威脅模型（第 31 章），以及 ICA 考試準備（第 32 章）。

## 30.1. control plane 的運作及影響效能的因素

讓我們回顧第 4 章：istiod（control plane）本身不處理流量。其任務是追蹤叢集狀態（服務、Pod、你的設定），並透過 xDS 向所有 Envoy **發送最新設定**。正是這項工作對 control plane 造成負載。

```mermaid
flowchart LR
    E["變更<br>(Pod / 設定)"] --> D["debounce / 批次處理"]
    D --> C["istiod 重新計算"]
    C --> P["透過 xDS 推送至所有 proxy"]
    style E fill:#673ab7,color:#fff
    style D fill:#f4b400,color:#000
    style C fill:#326ce5,color:#fff
    style P fill:#0f9d58,color:#fff
```

以下因素會影響 istiod 的效能：

- **服務與 Pod 的數量**--數量越多，需要計算與發送的設定越多。
- **變更頻率（churn）**--每個新 Pod、每次服務或規則變更都會觸發重新計算與發送。
- **已連線 proxy 的數量**--必須將設定傳送給每一個 proxy。
- **每個 proxy 的設定大小**--若每個 sidecar 都知道整個 mesh 的資訊（第 19 章），設定量會呈平方成長。

## 30.2. 監控 control plane

istiod 必須與應用程式分開監控。請以其「黃金訊號」為依據：

- **設定傳播延遲**--`pilot_proxy_convergence_time`。這是主要訊號：變更需花多久才能到達 proxy。數值上升是 control plane 無法負荷的第一個徵兆。
- **推送與錯誤**--`pilot_xds_pushes`（發送次數）以及被拒絕設定／xDS 錯誤的計數器。錯誤激增表示設定或連線出現問題。
- **已連線 proxy**--有多少 Envoy 連線至 istiod。
- **飽和度**--istiod 的 CPU 與記憶體。若達到限制，所有設定傳播都會受到影響。

這些指標是 control plane 告警的基礎（第 17 章）。即使 istiod 無法使用，正在運作的 proxy 仍會繼續以最後收到的設定運作，但新的變更不會送達--因此 istiod 的健康狀態至關重要。

**檢查你的工作。** istiod 黃金訊號的基本 PromQL 查詢：

```promql
# 設定收斂時間的 p99（秒）- 主要訊號
histogram_quantile(0.99, sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le))

# 依類型（cds/eds/lds/rds）統計的 xDS push 頻率
sum(rate(pilot_xds_pushes[5m])) by (type)

# 被拒絕的設定 - 應為 0
sum(rate(pilot_total_xds_rejects[5m]))

# 有多少 proxy 連線至 istiod
pilot_xds
```

收斂 p99 上升或 `pilot_total_xds_rejects` 非零，都是應深入調查的訊號：istiod 過載、設定損壞或連線問題。

## 30.3. 效能調校

主要的調校手段（其中許多已在前文提及）：

- **discovery selectors**（第 19 章）--istiod 僅追蹤必要的 namespace，忽略其他 namespace。若部分叢集不在 mesh 中，這是最大的效能收益。
- **Sidecar scope**（第 19 章）--每個 proxy 僅取得它所需服務的設定，而非整個 mesh。這會大幅降低設定量與 istiod 的負載。
- **事件批次處理與 debounce**--istiod 不會因每個微小變動就發送設定，而是在短暫區間內將變更分組（debounce），並限制推送頻率。這些參數（例如 `PILOT_DEBOUNCE_AFTER`、`PILOT_PUSH_THROTTLE`）會依負載調整：更多批次處理代表較少推送，但設定傳播延遲會稍微提高。
- **istiod 的資源與 HA**（第 27 章）--多個副本加上 HPA，以及足夠的 CPU／記憶體。
- **降低 churn**--減少不必要的變更（例如不需要時不要修改設定）= 更少重新計算。

批次處理參數會設定為 istiod 環境變數--在 `IstioOperator` 中透過 `components.pilot.k8s.env`：

```yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  components:
    pilot:
      k8s:
        env:
        - name: PILOT_DEBOUNCE_AFTER      # 在重新計算前等待靜默
          value: "100ms"
        - name: PILOT_DEBOUNCE_MAX        # 但不超過此上限
          value: "10s"
        - name: PILOT_PUSH_THROTTLE       # 同時 push 的上限
          value: "100"
```

較長的 debounce 在變更激增時代表更少的重新計算與推送，但傳播延遲會稍微提高（請監控 `pilot_proxy_convergence_time`，第 30.2 節）。預設值適合多數情境；應有意識地針對具體問題調整它們。

## 30.4. 部署策略：OPA Gatekeeper

在大型 mesh 中，重要的是避免團隊部署不安全或會造成問題的設定。此時可使用 **OPA Gatekeeper**--一個 admission controller，會在建立資源時檢查資源（如第 4 章的 webhook），並拒絕不符合規則的項目。

Istio 的常見策略包括：

- 對有應用程式的 namespace 要求注入標籤（或 `istio.io/rev`）；
- 禁止 `PeerAuthentication` 使用 `mode: DISABLE`（以免有人意外關閉 mTLS）；
- 要求 Service 的連接埠具有正確名稱（第 10 章）；
- 禁止過於寬鬆的 `AuthorizationPolicy` 或未經審核的 `EnvoyFilter`。

Gatekeeper 將本課程的最佳實務轉化為**自動強制執行的規則**：不再是「我們約定這樣做」，而是「否則根本無法部署」。

範例：禁止 `PeerAuthentication` 使用 `mode: DISABLE`。策略由兩種資源描述--`ConstraintTemplate`（要檢查什麼，以 Rego 撰寫）與 `Constraint`（套用至何處）：

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: denymtlsdisable
spec:
  crd:
    spec:
      names:
        kind: DenyMtlsDisable
  targets:
  - target: admission.k8s.gatekeeper.sh
    rego: |
      package denymtlsdisable
      violation[{"msg": msg}] {
        input.review.object.spec.mtls.mode == "DISABLE"
        msg := "政策禁止 PeerAuthentication mode DISABLE"
      }
---
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: DenyMtlsDisable
metadata:
  name: no-mtls-disable
spec:
  match:
    kinds:
    - apiGroups: ["security.istio.io"]
      kinds: ["PeerAuthentication"]
```

現在，任何停用 mTLS 的 `PeerAuthentication` 都會在 admission 時被拒絕--沒有人能意外在 mesh 上「開洞」。Gatekeeper 的替代方案是使用較簡單 YAML 語法（無須 Rego）的 **Kyverno**；兩者通常依團隊既有採用的工具而定。

## 30.5. EKS/AWS 上的營運

以下是幾個會影響 control plane、EKS 特有的注意事項。

- **透過受管服務監控 istiod。** 可將 istiod 的黃金訊號方便地寫入 **Amazon Managed Prometheus (AMP)**，並在 **Grafana (AMG)** 中檢視；指標則由 **ADOT** agent 收集（第 17 章）。istiod 也可運行於 **Fargate**（第 27 章）--它是 stateless 的。
- **Karpenter 與 spot node 會提高 churn。** node 自動擴展（Karpenter）與 spot 的中斷，表示 node 與 Pod 經常出現／消失。對 control plane 而言，這是**churn 增加**：每次重建 Pod 都會產生 endpoints 事件與新的 xDS 推送。可採取的措施包括：不要將 Karpenter 的 **consolidation** 設定得過於激進、對 node pool 設定 `disruption budget`、對應用程式設定 PDB--避免 node 持續被「重組」。同樣還要使用 scope（第 19 章），避免叢集某一部分的變更激增被發送給所有 proxy。
- **可觀測性成本。** Istio 指標具有高基數；在大型 EKS 叢集上，AMP／儲存費用會快速上升--請透過 Telemetry API（第 18 章）管理：停用不必要的度量，並合理地對 trace 進行取樣。

## 30.6. 大規模營運：檢查清單

以下彙整整個課程中分散的營運實務：

- **監控 control plane**（istiod 黃金訊號），不只監控應用程式。
- 在大型叢集上**最佳化 scope**（discovery selectors + Sidecar）--這是主要的效能手段。
- **透過 revision/canary 更新**（第 3 章），不要在運作中的生產環境直接 in-place 更新。
- **及早規劃 PKI 與共用 CA**（第 16、28 章），並規劃根憑證輪替。
- 在多叢集的各叢集中**維持一致的 Istio 版本**（第 28 章）。
- 透過 Gatekeeper **自動化策略**--將最佳實務作為強制規則。
- 針對整個 mesh 進行**可觀測性**與告警（第 17–18 章），並合理取樣。
- 在實際需要之前，**演練更新與回滾**。
- **不要過早增加複雜度**--請因應具體需求才引入 ambient、多叢集、VM，而不是「因為可以」。

## 30.7. 本章總結

- Control plane（istiod）不承載流量，但會計算並向所有 proxy 發送設定；這就是它的負載來源。
- 效能取決於服務／Pod 數量、變更頻率、proxy 數量，以及每個 proxy 的設定大小。
- 監控 istiod 的黃金訊號：設定傳播時間（`pilot_proxy_convergence_time`）、推送與錯誤、proxy 數量、CPU／記憶體。
- 調校：**discovery selectors** 與 **Sidecar scope**（第 19 章）、推送的批次處理／throttle（透過 `IstioOperator` 的 `PILOT_DEBOUNCE_AFTER`／`PILOT_PUSH_THROTTLE`）、istiod 的資源與 HA，以及降低 churn。
- **OPA Gatekeeper**（或 Kyverno）可將最佳實務轉為強制 admission 規則（`ConstraintTemplate` + `Constraint`），例如禁止 mTLS `DISABLE`。
- 在 EKS 上：透過 AMP/AMG/ADOT 監控 istiod，istiod 可運行在 Fargate；**Karpenter/spot** 會提高 churn--限制 consolidation 並維持狹窄的 scope；監控高基數指標的成本。
- 大規模營運：監控 control plane、最佳化 scope、透過 revision 更新、及早規劃 PKI、統一版本、自動化策略、端對端可觀測性、演練回滾，以及避免不必要的複雜度。

## 30.8. 自我檢查問題

1. 若 control plane 不處理使用者流量，它的負載來自什麼？
2. 哪些因素會影響 istiod 的效能？
3. 請列出 control plane 的黃金訊號，以及 `pilot_proxy_convergence_time` 上升代表什麼。
4. 你知道哪些效能調校手段？如何設定 istiod 的批次處理參數？
5. 在 Istio 營運的情境中，OPA Gatekeeper 有什麼作用？策略由哪些資源組成，又可用什麼替代？
6. 你會使用哪些 PromQL 查詢檢查 control plane 的健康狀態？
7. Karpenter 與 spot node 如何影響 istiod 的負載，應如何處理？

## 實作

實際練習營運與效能：discovery selectors 與 Sidecar scope、監控 istiod 黃金訊號，以及透過 OPA Gatekeeper 實施部署策略。

🧪 實驗 33：[tasks/ica/labs/33](../../labs/33/README_TW.MD)

---
[目錄](../README_TW.md) · [第 29 章](../29/tw.md) · [第 31 章](../31/tw.md)
