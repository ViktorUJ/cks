[Русская версия](ADR_RU.md) · [Eng version](ADR.md) · [Versión en español](ADR_ES.md) · [Version française](ADR_FR.md) · [Deutsche Version](ADR_DE.md) · [ქართული ვერსია](ADR_GE.md) · [日本語版](ADR_JP.md)

# EKS 課程的架構決策紀錄（ADR）

[課程目錄](README_TW.md) · [詞彙表](GLOSSARY_TW.md)

## 使用方式

ADR（Architecture Decision Record，架構決策紀錄）是關於單一決策的簡短記錄：為何如此選擇、
有哪些方案，以及為此選擇付出的代價。目的不是為文件而文件，而是避免一年後重新爭論，
並讓新加入團隊的人理解動機，而不只是結果。

下列範本已填入課程內容：選項、其優點和代價取自各章，而非在此臆造。不過，**情境、狀態、
日期和決策本身應由工程師**依據自己的專案填寫：課程不知道您的叢集群、合規需求，
以及是否有平台團隊。

「被否決的選項」不代表「不佳」。在課程幾乎所有的分岔中，兩個選項都可行，而被否決的
選項會在不同輸入條件下成為正確選擇，這正是「重新審視條件」欄位存在的理由。

## 空白範本

```markdown
## ADR-NN. 決策的簡短名稱

狀態：提議 / 已採用 / 已否決 / 取代 ADR-NN
日期：YYYY-MM-DD

**情境。** 要解決什麼問題、有哪些限制、必須釐清哪些問題。

**已考慮的選項。**

| 選項 | 提供什麼 | 付出什麼代價 | 何時適用 |
|---|---|---|---|
|  |  |  |  |

**已採用決策的後果。**

- 獲得什麼：
- 付出什麼代價：

**決策。** 選擇了什麼，以及適用範圍（整個叢集群、單一叢集、試行）。

**重新審視條件。** 會重新開啟此記錄的具體觸發條件。

**參考資料。** 課程章節和專案內部文件。
```

## ADR-01. 運算：EKS Auto Mode 與自管 Karpenter 堆疊

狀態：_由工程師填寫_
日期：_由工程師填寫_

**情境。** 選擇前請回答：

- 安全性是否要求節點映像檔（已證明的 AMI、自訂 bootstrap）；
- 是否需要存取節點以進行除錯，或以 DaemonSet 執行節點代理程式；
- 是否需要非 VPC CNI，並控制 Karpenter 控制器本身，而不只是 NodePool；
- 成本有多關鍵：EC2 之上的管理加價是否可接受；
- 是否有準備好維護節點的團隊，或目標就是將維運降至最低。

**已考慮的選項。**

| 選項 | 提供什麼 | 付出什麼代價 | 何時適用 |
|---|---|---|---|
| EKS Auto Mode | 節點如同 appliance：Bottlerocket、強制 SELinux、唯讀 root、輪替不超過 21 天、內建 Karpenter、IPAM、network policy、EBS CSI、ELB、Pod Identity | EC2 之上的管理加價（不適用 Reserved 和 Savings Plans 折扣）、無 SSH 和 SSM、無法修改預設 NodePool 和 NodeClass、不能使用其他 CNI | 目標是將節點維運降至最低，且不要求節點映像檔及節點存取 |
| 自管堆疊：managed node groups 或 self-managed 加上自管 Karpenter | 自訂 launch template 和 AMI、節點存取、任意 CNI、完全掌控 Karpenter 版本與設定 | 節點、附加元件、升級和中斷處理由您負責，僅支付 EC2 費用 | 有 Auto Mode 無法滿足的要求，或經濟性無法承受加價 |

**已採用決策的後果。**

- 獲得什麼：每個叢集使用單一節點維運模型，AWS 與團隊之間有可預期的責任邊界。
- 付出什麼代價：在 Auto Mode 中，容器、叢集與 VPC 設定、來自 PVC 的磁碟區以及
  負載平衡器仍由您負責；自訂 NodePool 不會繼承預設項目的限制，因此必須手動指定限制和
  執行個體類型，否則集區會無上限成長。

**決策。** _依據自己的專案填寫_

**重新審視條件。** 出現對已證明節點映像檔的要求；需要無法以 sidecar 執行的節點代理程式；
需要將 Cilium 作為主要 CNI；disruption budgets 阻止更新的時間超過節點生命週期；叢集群成長至
節點替換造成的尖峰和管理加價在帳單中明顯可見的規模。

**參考資料。** [第 9 章](09/tw.md) - 運算類型，第 9.6 至 9.8 節；
[第 10 章](10/tw.md) - launch template 與自訂 AMI；[第 12 章](12/tw.md) - NodePool 與
 disruption；[第 43 章](43/tw.md) - 成本分析。

## ADR-02. Pod 身分：IRSA 與 EKS Pod Identity

狀態：_由工程師填寫_
日期：_由工程師填寫_

**情境。** 選擇前請回答：

- 有多少個叢集，角色是否在它們之間移轉；
- 是否有在 Fargate 或 Windows 節點上執行的工作負載；
- 是否需要在相同角色上使用 EKS 以外的身分（EC2、ECS、Lambda）；
- 是否需要跨帳戶，以及採用何種形式；
- 現有叢集的 platform version 是什麼。

**已考慮的選項。**

| 選項 | 提供什麼 | 付出什麼代價 | 何時適用 |
|---|---|---|---|
| IRSA | 透過 STS 的 OIDC federation、可於 EKS 外運作、直接跨帳戶、支援 Fargate 與 Windows 節點 | 每個叢集一個 IAM OIDC provider、必須為每個叢集重寫 trust policy、手動處理 session tags | Fargate、Windows、EKS 外的身分、透過 federation 的跨帳戶 |
| EKS Pod Identity | 所有叢集共用一條針對 `pods.eks.amazonaws.com` 的 trust policy、透過 EKS API 的 association 繫結而無需 annotation、內建 session tags 和 ABAC | 僅支援 Linux Amazon EC2 節點，不支援 Fargate、Windows、Outposts 和 EKS Anywhere，需要附加元件代理程式及最低 platform version | 使用 EC2 節點的新叢集，以及角色可重複使用的叢集群 |

**已採用決策的後果。**

- 獲得什麼：向 Pod 授與權限的統一方式，以及角色在哪裡綁定至 ServiceAccount 的單一明確事實來源。
- 付出什麼代價：混合叢集群必須保留兩種模型；在同一個 ServiceAccount 同時設定兩者時，
  IRSA 會勝出，因為 web identity 在 SDK 鏈結中位於容器提供者之前，Pod Identity association
  會被靜默忽略。

**決策。** _依據自己的專案填寫_

**重新審視條件。** 叢集群新增 Fargate profiles 或 Windows 節點；出現依 session tags 實作 ABAC 的
要求；文件中的 Pod Identity 限制減少；需要讓 EKS 內外的工作負載使用同一角色。

**參考資料。** [第 16 章](16/tw.md) - IRSA 與 OIDC provider；[第 17 章](17/tw.md) - Pod
Identity、比較和遷移順序。

## ADR-03. 網路：VPC CNI 與 Cilium（chaining 或完整替換）

狀態：_由工程師填寫_
日期：_由工程師填寫_

**情境。** 選擇前請回答：

- 是否需要 L7（HTTP、gRPC、Kafka）或依 DNS 名稱的 policy，以及由誰撰寫；
- 是否需要 Hubble 層級的 Pod 間流量可觀測性；
- VPC 中真實的 Pod 位址、security groups for pods，以及依 Pod 劃分的 Flow Logs 是否重要；
- 是否無法以其他方式解決 IPv4 不足；
- 團隊是否準備好掌控 CNI 升級及其與叢集版本的相容性。

**已考慮的選項。**

| 選項 | 提供什麼 | 付出什麼代價 | 何時適用 |
|---|---|---|---|
| 具內建 NetworkPolicy 的 VPC CNI | managed addon、AWS 支援、標準升級、標準 `NetworkPolicy` L3/L4 與管理用 `ClusterNetworkPolicy`、真實 VPC 位址 | 沒有 L7 規則、沒有依 FQDN 的 policy、沒有 Cilium CRD 和 Hubble | 需要 L3/L4 隔離，且 VPC 位址模型符合需求 |
| CNI chaining 模式的 Cilium | `CiliumNetworkPolicy`、L7 和 DNS policy、Hubble，同時 IPAM 和 VPC 整合仍由 VPC CNI 負責 | 自行安裝與維護 Cilium、第二套 CRD 模型、團隊培訓 | 需要 L7 或 DNS policy 或 Hubble，且位址模型符合需求 |
| Cilium 作為完整替換（ENI IPAM 或 cluster-pool） | 自有 IPAM、可選的 overlay 與擺脫 IPv4 不足、ClusterMesh、以 eBPF 取代 kube-proxy | 升級與相容性由您負責、AWS 支援範圍縮小、使用 overlay 時會失去真實 Pod 位址、SG for pods 及 Flow Logs 中的 Pod 位址 | 需要 overlay 或多叢集網路，或有 ENI 模型無法滿足的要求 |

**已採用決策的後果。**

- 獲得什麼：AWS 支援所涵蓋內容與平台團隊所掌控內容之間的明確邊界。
- 付出什麼代價：無法透過切換旗標來更換 CNI，CNI 會在 Pod 建立時指派，因此轉換是經由
  新節點集區或新叢集進行的 blue/green；故障診斷會移至 CNI 工具；另需為 Pod 啟動時的無 policy
  時段預留空間（`NETWORK_POLICY_ENFORCING_MODE` 的 `standard` 模式會提供 default allow）。

**決策。** _依據自己的專案填寫_

**重新審視條件。** 出現對 L7 或依 DNS 名稱 policy 的要求；需要 Pod 間流量地圖；IPv4 不足已無法
透過第 7 章的工具解決；需要跨多個叢集的共用 Pod Network；iptables kube-proxy 成為瓶頸。

**參考資料。** [第 8 章](08/tw.md) - 替代 CNI、轉換代價、遷移；
[第 6 章](06/tw.md) - 透過 ENI 的 Pod 定址；[第 7 章](07/tw.md) - 位址不足；
[第 30 章](30/tw.md) - 生產環境中的 network policy。

## ADR-04. 節點自動擴縮：Cluster Autoscaler 與 Karpenter

狀態：_由工程師填寫_
日期：_由工程師填寫_

**情境。** 選擇前請回答：

- 叢集使用 Auto Mode 還是自管堆疊（Auto Mode 已解決此問題，Karpenter 已內建）；
- 工作負載的異質性有多高，需要維護多少個 node group；
- 是否要求快速回應流量尖峰；
- 是否需要以一個工具統一管理其他雲端中的叢集；
- CA 是否已部署、調校完成，並且真的造成問題。

**已考慮的選項。**

| 選項 | 提供什麼 | 付出什麼代價 | 何時適用 |
|---|---|---|---|
| Cluster Autoscaler | 在 Auto Scaling group 之上運作、許多 provider 的統一方式、無需新 CRD 的既有維運流程 | 在 group 而非 Pod 層級回應；執行個體類型集合固定於 launch template；因 ASG 層而較慢；會移除空節點，但不會整併 | 簡單且可預期的叢集、多雲統一、既有運作中的安裝 |
| Karpenter | 直接呼叫 EC2、依特定 Pod 選擇執行個體類型、主動 consolidation、為 spot 分散執行個體類型 | 自有 CRD `NodePool` 和 `EC2NodeClass`、掌控控制器版本和設定、AWS-first | EKS 上的新叢集、異質工作負載、要求速度與緊密裝箱 |

**已採用決策的後果。**

- 獲得什麼：一個負責建立與移除節點的機制，以及一處設定叢集群限制的位置。
- 付出什麼代價：只能讓兩者同時管理不同的節點集合，且僅能作為暫時的遷移模式，否則它們會
  爭奪 scale-down 決策；遷移透過新節點進行，而不是在運作中的節點上搬移 Pod。

**決策。** _依據自己的專案填寫_

**重新審視條件。** node group 的雜湊園地成長至無法管理；因裝箱不佳造成的浪費在帳單中變得明顯；
對流量尖峰的回應不再符合 SLO；叢集遷移至 Auto Mode；其他雲端出現要求使用單一工具的叢集。

**參考資料。** [第 11 章](11/tw.md) - 方法比較與選擇清單；
[第 12 章](12/tw.md) - NodePool、consolidation、disruption budgets；
[第 13 章](13/tw.md) - spot；[第 9 章](09/tw.md) - 與 Auto Mode 的關係。

## ADR-05. 叢集群的 GitOps：hub-and-spoke 與去中心化

狀態：_由工程師填寫_
日期：_由工程師填寫_

**情境。** 選擇前請回答：

- 目前叢集群中有多少個叢集，預期將有多少個；
- 在失去 hub 或與 hub 的連線時，叢集是否必須自主運作；
- 是否需要整個叢集群的統一概觀面板；
- 由誰更新代理程式，團隊是否已準備好面對其版本分歧；
- 跨叢集邊界的 reconciliation 流量成本是多少。

**已考慮的選項。**

| 選項 | 提供什麼 | 付出什麼代價 | 何時適用 |
|---|---|---|---|
| Hub-and-spoke | hub 上的一個 Argo CD 或 Flux 執行個體，不必在每個叢集安裝代理程式，ApplicationSet 透過 cluster 和 git generator 搭配 matrix 將一組附加元件部署至整個叢集群，提供統一概觀 | hub 是故障域：spoke 上的工作負載持續運作，但套用 commit、self-heal 與回復會在整個叢集群停止；透過網路 reconciliation 會帶來延遲、輸出流量費用與連線敏感性 | 重視維運簡易性與統一概觀的小型及中型叢集群 |
| Hub 分片 | 叢集分配至 application-controller replicas，replica 數量在 `ARGOCD_CONTROLLER_REPLICAS` 中重複設定 | 仍是一個故障域；以 hash 為基礎的分配不均，round-robin 較平均 | 叢集群已超出單一控制器能力，但不需要叢集自主性 |
| 去中心化 | hub 僅部署基礎項目與本機代理程式，之後叢集自行從 Git 拉取，並在失去 hub 時保持自主 | 代理程式數量與叢集相同，必須更新與設定；沒有統一面板；代理程式版本會分歧 | 大型叢集群或嚴格要求自主性 |
| argocd-agent | 一個中央 Argo CD 執行個體可檢視所有叢集的 `Application`，但同步由 spoke 端的代理程式拉取 | `argoproj-labs` 專案仍在孵化，非 Argo CD 核心；拓撲仍為 hub-and-spoke | 願意為反向流量使用孵化專案 |

**已採用決策的後果。**

- 獲得什麼：對「hub 不可用時交付會如何」這個問題有明確答案。
- 付出什麼代價：無論採用何種拓撲，IaC 與 GitOps 的邊界都必不可少：基礎設施（VPC、叢集、
  node groups、IAM）透過 Terraform，而附加元件和工作負載透過 GitOps；混用會造成為了修改
  Deployment 而重建叢集，或代理程式存在於同一叢集時的先有雞還是先有蛋問題。

**決策。** _依據自己的專案填寫_

**重新審視條件。** 叢集群成長至單一控制器無法處理；出現失去 hub 時仍須持續 reconciliation 的要求；
reconciliation 的輸出流量費用變得明顯；argocd-agent 結束孵化期。

**參考資料。** [第 44 章](44/tw.md) - 叢集群拓撲，第 44.6 節；
[第 32 章](32/tw.md) - 叢集群；[第 4 章](04/tw.md) - IaC 與 Terraform；
[第 31 章](31/tw.md) - 流量成本；[第 38 章](38/tw.md) - blue/green 遷移。

## 此處刻意不處理的事項

課程不會將部分分岔視為架構決策：其中的技術大致等價，決定因素是公司的情境。選擇 Argo CD
或 Flux，取決於團隊已熟悉哪一種以及需要何種介面，而非工具的特性。選擇自管 Prometheus
或 managed service，取決於誰負責值班以及儲存成本，而非指標收集的架構。映像檔 registry、
secret 工具與帳戶配置也是如此：它們屬於組織邊界。部署至生產環境前必須檢查事項的彙總清單，
請見[第 48 章](48/tw.md)。
