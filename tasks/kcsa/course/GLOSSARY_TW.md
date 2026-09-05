[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [日本語版](GLOSSARY_JP.md)

# KCSA 課程詞彙表

英文術語保留原文，因為閱讀 KCSA 題目與選項時需要使用它們。說明以繁體中文解釋含義，但不能取代對英文 MCQ (multiple choice question，選擇題) 術語的練習。

| 術語 | 說明 | 常見混淆 | 章節 |
|---|---|---|---|
| `4C model` | 用於分析 cloud native 防護的 Cloud、Cluster、Container 與 Code 分層模型。 | 不僅限於雲端基礎設施。 | [03](03/tw.md) |
| `ABAC` | 依請求與主體屬性進行授權。 | 不是使用角色的 RBAC。 | [10](10/tw.md) |
| `Access control` | 依規則與身分限制資源存取。 | 範圍比單純的 authentication 更廣。 | [10](10/tw.md) |
| `admission` | 在 authentication 與 authorization 後，檢查或修改 API 請求的階段。 | 請依脈絡理解術語，不要以相近概念替代。 | [07](07/tw.md) |
| `Admission control` | authentication 與 authorization 後，允許或修改物件的 API 階段。 | 不會確認 identity，也不會授予權限。 | [11](11/tw.md), [17](17/tw.md) |
| `Admission policy` | 在 admission 期間檢查物件的宣告式規則。 | 不等同於 audit policy。 | [17](17/tw.md) |
| `Admission webhook` | 參與 mutating 或 validating admission 的外部 webhook。 | 不是應用程式的網路 webhook。 | [17](17/tw.md) |
| `Alert` | 依規則要求注意或回應的訊號。 | 無法取代原始日誌與指標。 | [18](18/tw.md) |
| `Allowlist` | 明確列出的允許來源、動作或物件。 | 不等於沒有 deny 規則。 | [09](09/tw.md), [17](17/tw.md) |
| `Anomaly detection` | 偵測偏離預期行為的情況。 | 異常本身不能證明遭受攻擊。 | [18](18/tw.md) |
| `API server` | 接收 Kubernetes API 請求並協調狀態存取的元件。 | 不會代替 etcd 儲存狀態。 | [07](07/tw.md) |
| `Artifact` | 開發或建置產物，例如 image、套件或 SBOM。 | 不一定是 container image。 | [06](06/tw.md), [17](17/tw.md) |
| `Attack surface` | 系統可遭受攻擊的所有進入點。 | 不是單一已發現的弱點。 | [02](02/tw.md), [16](16/tw.md) |
| `Attack vector` | 執行攻擊的具體路徑或方法。 | 比 attack surface 的範圍更窄。 | [15](15/tw.md), [16](16/tw.md) |
| `audit` | PSA 模式，將違規記錄到稽核但不拒絕請求。 | 請依脈絡理解術語，不要以相近概念替代。 | [11](11/tw.md) |
| `Audit backend` | 用來儲存或傳送 API Server audit 事件的設定位置。 | API Server 建立事件，backend 負責儲存或接收。 | [14](14/tw.md) |
| `audit event` | `kube-apiserver` 對 Kubernetes API 請求處理的記錄。 | 請依脈絡理解術語，不要以相近概念替代。 | [14](14/tw.md) |
| `audit level` | Kubernetes audit 事件的詳細程度，例如 `Metadata` 或 `RequestResponse`。 | 請依脈絡理解術語，不要以相近概念替代。 | [20](20/tw.md) |
| `Audit logging` | 記錄 Kubernetes API 請求事件。 | 無法取代程序的 runtime detection。 | [14](14/tw.md) |
| `Audit policy` | 決定記錄哪些 API 事件及其詳細程度的設定。 | 不是 admission policy。 | [14](14/tw.md) |
| `auditID` | 關聯同一請求不同處理階段事件的識別碼。 | 請依脈絡理解術語，不要以相近概念替代。 | [14](14/tw.md) |
| `Authentication` | 判定誰提出請求。 | 不回答該動作是否被允許。 | [10](10/tw.md) |
| `Authorization` | 檢查已知主體是否能執行動作。 | 不會建立 identity。 | [10](10/tw.md) |
| `Authorization mode` | 設定好的 API 權限決策機制。 | 不等同於 authentication 方法。 | [10](10/tw.md) |
| `Availability` | 授權使用者可存取資料或服務。 | 不等同於機密性或完整性。 | [02](02/tw.md), [16](16/tw.md) |
| `Backup` | 用於遺失或損毀後復原的資料複本。 | Backup 也必須像原始資料一樣受到保護。 | [07](07/tw.md), [12](12/tw.md) |
| `Base64` | 將位元組轉為文字表示的可逆編碼。 | 不是 encryption。 | [12](12/tw.md) |
| `baseline` | 阻擋常見權限提升途徑的設定檔。 | 請依脈絡理解術語，不要以相近概念替代。 | [11](11/tw.md) |
| `Baseline profile` | 在保有相容性的同時阻擋已知危險設定的 PSS 等級。 | 不等同於最嚴格的 restricted profile。 | [11](11/tw.md) |
| `Bearer token` | 持有者只要出示即可取得其權限的 token。 | 不等同於可安全放進程式碼的密碼。 | [10](10/tw.md) |
| `bind` | 可繫結 Role/ClusterRole 的特殊 RBAC 權限，無須自行擁有該角色全部 permissions。 | 請依脈絡理解術語，不要以相近概念替代。 | [10](10/tw.md) |
| `blast radius` | 單一元件遭入侵時的影響範圍。 | 請依脈絡理解術語，不要以相近概念替代。 | [16](16/tw.md) |
| `Bound ServiceAccount token` | 繫結 ServiceAccount 與 Pod 的短效 token。 | 不等同於舊式長效 Secret token。 | [10](10/tw.md) |
| `Build provenance` | 含有 artifact 建置資訊的 Provenance。 | 不等同於 signature 或 SBOM。 | [17](17/tw.md), [19](19/tw.md) |
| `CA` | 受信任、可簽發或驗證 certificate 的憑證機構。 | 不是 private key。 | [18](18/tw.md) |
| `capability` | 可獨立於 UID 0 授予或撤除的單項 Linux 權限。 | 請依脈絡理解術語，不要以相近概念替代。 | [09](09/tw.md) |
| `CEL` | Common Expression Language，Kubernetes API 內建的運算式語言，可在不執行任意程式碼下定義條件與規則。 | 不是可執行任意程式碼的通用語言。 | [17](17/tw.md) |
| `Certificate` | 由受信任 CA 簽署，包含 public key 與 identity 的文件。 | 不含 private key。 | [18](18/tw.md) |
| `Certificate authority` | 作為 PKI 受信任方的 CA 全名。 | 不等同於任何 TLS certificate。 | [18](18/tw.md) |
| `CIA triad` | 三項安全目標：confidentiality、integrity 與 availability。 | 不是 threat model 或 control。 | [02](02/tw.md), [15](15/tw.md) |
| `Cilium` | 能套用 NetworkPolicy 的 CNI 與網路工具組。 | 不是 NetworkPolicy API 資源本身。 | [13](13/tw.md) |
| `CIS Kubernetes Benchmark` | Kubernetes 安全設定建議的集合。 | 是建議 framework，不是現成 control。 | [05](05/tw.md), [19](19/tw.md) |
| `CKS` | Certified Kubernetes Security Specialist，以 Kubernetes 安全為主的實作型 performance-based 認證。 | 請依脈絡理解術語，不要以相近概念替代。 | [01](01/tw.md) |
| `Cloud` | 4C 模型外部層：供應商的基礎設施、IAM 與服務。 | 不等同於 Kubernetes cluster。 | [03](03/tw.md), [04](04/tw.md) |
| `Cloud IAM` | 雲端資源的 identity 與權限管理。 | 無法取代 Kubernetes RBAC。 | [04](04/tw.md) |
| `Cluster-admin` | 對所有 cluster 資源具無限制權限的內建 ClusterRole。 | 不應作為日常 identity 使用。 | [10](10/tw.md), [16](16/tw.md) |
| `ClusterRole` | 無 namespace 範圍的允許 API 動作集合，適用 cluster 資源或所有 namespace。 | 不等同於僅限單一 namespace 的 Role。 | [10](10/tw.md) |
| `ClusterRoleBinding` | 在全 cluster 層級將 subject 與 ClusterRole 繫結。 | 不等同於只在一個 namespace 生效的 RoleBinding。 | [10](10/tw.md) |
| `CNI` | 將 container 連接到 Kubernetes 網路的標準與 plugin。 | 請依脈絡理解術語，不要以相近概念替代。 | [09](09/tw.md), [13](13/tw.md) |
| `Code` | 4C 的原始碼、dependencies 與開發實務層。 | 不等同於已建置的 image。 | [03](03/tw.md), [06](06/tw.md) |
| `Compliance` | 符合適用要求，且有可驗證 evidence。 | 不保證不存在所有風險。 | [19](19/tw.md) |
| `Confidentiality` | 保護資料不向未授權方洩露。 | 不等同於 integrity 或 availability。 | [02](02/tw.md), [12](12/tw.md) |
| `Container` | 具有 image 與 runtime 限制的隔離程序。 | 不等同於可能包含多個 container 的 Pod。 | [03](03/tw.md), [09](09/tw.md) |
| `container escape` | 程序從 container 隔離環境逃逸至工作節點資源。 | 請依脈絡理解術語，不要以相近概念替代。 | [16](16/tw.md) |
| `Container image` | 用於啟動 container 的不可變檔案與 metadata 範本。 | 不等同於執行中的 container。 | [06](06/tw.md), [17](17/tw.md) |
| `Container registry` | 儲存及散布 container images 的服務。 | 請依脈絡理解術語，不要以相近概念替代。 | [06](06/tw.md) |
| `Container runtime` | 透過 CRI 在節點啟動 container 的軟體層。 | 不等同於 kubelet。 | [08](08/tw.md) |
| `context` | `kubectl` 使用的 cluster、user 與 namespace 選擇。 | 請依脈絡理解術語，不要以相近概念替代。 | [09](09/tw.md) |
| `Control` | 降低風險機率或後果的具體措施。 | 不等同於用來組織措施的 framework。 | [05](05/tw.md), [19](19/tw.md) |
| `Control plane` | 管理 Kubernetes 狀態的邏輯元件集合。 | 不等同於 worker node。 | [07](07/tw.md) |
| `Controller Manager` | 執行 controllers，使狀態趨近所需狀態的元件。 | 不會為 Pod 選擇節點。 | [07](07/tw.md) |
| `CRI` | kubelet 與 container runtime 之間的 Kubernetes 介面。 | 不是 CNI 或 CSI。 | [08](08/tw.md) |
| `CronJob` | 依排程建立 Job 的 Kubernetes 資源。 | 攻擊者可用於在 cluster 中維持存取，不只用於原定用途。 | [16](16/tw.md) |
| `CVE` | 公開已知 vulnerability 的識別碼。 | CVE 不等同於已證實被利用。 | [06](06/tw.md), [16](16/tw.md) |
| `Data flow` | 系統參與者間傳輸資料的路徑。 | 不等同於 trust boundary，但可能穿越它。 | [15](15/tw.md) |
| `Default deny` | 預設拒絕未明確允許流量的起始 policy。 | 不等同於拒絕所有 API 存取。 | [13](13/tw.md) |
| `default-deny` | 在指定方向上，流量未被明確 policy 允許前一律拒絕的方法。 | 請依脈絡理解術語，不要以相近概念替代。 | [13](13/tw.md) |
| `Defense in depth` | 結合獨立防護層。 | 不表示重複同一個 control。 | [02](02/tw.md), [05](05/tw.md) |
| `Denial of Service` | 因資源耗盡或超載而破壞 availability。 | 不等同於系統任何變慢。 | [16](16/tw.md) |
| `Deployment` | 管理 ReplicaSet 與 Pod 更新的 Kubernetes 資源。 | 不是獨立的安全邊界。 | [02](02/tw.md), [09](09/tw.md) |
| `Detection` | 偵測已觀察到的事件或偏差。 | 不會在物件建立前預防它。 | [14](14/tw.md), [18](18/tw.md) |
| `Digest` | 某個 artifact 具體內容的密碼學識別碼。 | 不證明作者、安全性或來源。 | [06](06/tw.md), [17](17/tw.md) |
| `distractor` | 看似合理但錯誤的答案選項。 | 請依脈絡理解術語，不要以相近概念替代。 | [20](20/tw.md) |
| `Distroless` | 沒有一般 shell 與 package manager 的最小 runtime image。 | 請依脈絡理解術語，不要以相近概念替代。 | [06](06/tw.md) |
| `DNS` | 解析服務名稱與外部位址的服務。 | 不是 network segmentation 機制。 | [09](09/tw.md) |
| `DoS` | 因資源耗盡或超載造成的拒絕服務。 | 請依脈絡理解術語，不要以相近概念替代。 | [16](16/tw.md) |
| `Egress` | 從選定 Pod 發出的網路流量。 | 不等同於流入 Pod 的 ingress 流量。 | [13](13/tw.md), [18](18/tw.md) |
| `Encryption` | 使用 key 的資料密碼學保護。 | 不等同於可逆 encoding。 | [04](04/tw.md), [12](12/tw.md) |
| `Encryption at rest` | 對已儲存資料進行加密，例如 etcd 中的資料。 | 不保護具有讀取權限主體的 API 讀取。 | [07](07/tw.md), [12](12/tw.md) |
| `Encryption in transit` | 在網路傳輸期間加密資料。 | 無法取代 authorization 或 segmentation。 | [04](04/tw.md), [18](18/tw.md) |
| `EncryptionConfiguration` | API Server 用於加密 etcd 中 API 資源的設定。 | 不是 RBAC policy。 | [12](12/tw.md) |
| `Endpoint` | 服務或元件的網路存取位址或點。 | 並非所有脈絡都等同 Kubernetes EndpointSlice。 | [04](04/tw.md), [09](09/tw.md) |
| `enforce` | 會拒絕違反規則 `Pod` 的 PSA 模式。 | 請依脈絡理解術語，不要以相近概念替代。 | [11](11/tw.md) |
| `envelope encryption` | 以資料 key 加密資料，再以 KMS key 保護該 key 的方法。 | 請依脈絡理解術語，不要以相近概念替代。 | [12](12/tw.md) |
| `escalate` | 可建立或修改 Role/ClusterRole，且其 permissions 超過 caller 自身 permissions 的特殊 RBAC 權限。 | 請依脈絡理解術語，不要以相近概念替代。 | [10](10/tw.md) |
| `Etcd` | Kubernetes control plane 的狀態儲存庫。 | 不是 API Server。 | [07](07/tw.md), [12](12/tw.md) |
| `Evidence` | 可驗證 control 或程序運作的證據。 | 不等同於 compliance 要求本身。 | [14](14/tw.md), [19](19/tw.md) |
| `Exploit` | 利用 vulnerability 的程式碼或技術。 | 不是每個 vulnerability 都有已知 exploit。 | [16](16/tw.md) |
| `External Secrets Operator` | 從外部儲存庫同步 secrets 的 Operator。 | 同步後仍存在 Kubernetes Secret 的風險。 | [12](12/tw.md) |
| `Falco` | 偵測 container 與節點行為的 runtime detection 工具。 | 無法取代 API 請求的 audit logging。 | [16](16/tw.md), [18](18/tw.md) |
| `Firewall` | 在指定邊界篩選流量的網路 control。 | 不等同 Kubernetes 內的 NetworkPolicy。 | [04](04/tw.md) |
| `FQDN` | 網路目標的完整網域名稱。 | 不是 IP 位址或 identity。 | [09](09/tw.md), [18](18/tw.md) |
| `Framework` | 評估風險、要求或 controls 完整度的結構。 | 本身不是技術 control。 | [05](05/tw.md), [19](19/tw.md) |
| `Grafana` | 依 observability 資料建立 dashboard 與 alert 的工具。 | 請依脈絡理解術語，不要以相近概念替代。 | [18](18/tw.md) |
| `gVisor` | 在 workload 與節點 kernel 間增加隔離的 Sandbox runtime。 | 無法取代 PSS、RBAC 與 NetworkPolicy。 | [05](05/tw.md) |
| `hard multi-tenancy` | 以強而通常是基礎設施邊界隔離 tenants。 | 請依脈絡理解術語，不要以相近概念替代。 | [05](05/tw.md) |
| `Hash` | hash function 的結果，用於驗證資料一致性。 | 不是可驗證作者的 signature。 | [06](06/tw.md), [17](17/tw.md) |
| `HIPAA` | 美國醫療資訊保護規範。 | 不是 Kubernetes 資源。 | [19](19/tw.md) |
| `hostPath` | 將 worker node 檔案系統路徑掛載至 `Pod` 的 volume。 | 請依脈絡理解術語，不要以相近概念替代。 | [09](09/tw.md) |
| `Hubble` | Cilium 網路流量的觀察工具。 | 請依脈絡理解術語，不要以相近概念替代。 | [18](18/tw.md) |
| `Identity` | 執行動作主體的表示。 | 不等同於一組 permissions。 | [10](10/tw.md), [18](18/tw.md) |
| `Image digest` | 用來固定 image 特定內容的 Digest。 | 不等同於 mutable tag。 | [06](06/tw.md), [17](17/tw.md) |
| `Image policy` | 依來源、signature 或屬性允許 image 的規則。 | 不是 scanner 報告。 | [17](17/tw.md) |
| `image registry` | 儲存 container images 與相關 metadata 的倉庫。 | 請依脈絡理解術語，不要以相近概念替代。 | [17](17/tw.md) |
| `Image tag` | 可變更的人類可讀 image 標籤。 | 請依脈絡理解術語，不要以相近概念替代。 | [06](06/tw.md) |
| `impersonate` | 傳統 Kubernetes 的 impersonation 他人 identity 權限；v1.36 另有 verbs 更受限的 beta ConstrainedImpersonation。 | 請依脈絡理解術語，不要以相近概念替代。 | [10](10/tw.md) |
| `Incident response` | 事件發生後的偵測、遏制與復原準備及行動。 | 不限於蒐集日誌。 | [14](14/tw.md), [16](16/tw.md) |
| `Ingress` | 流入選定 Pod 的網路流量。 | 不等同於 HTTP 路由的 Ingress 物件。 | [13](13/tw.md), [18](18/tw.md) |
| `Integrity` | 資料在未經允許下保持正確且未被修改的特性。 | 不等同於 confidentiality。 | [02](02/tw.md), [19](19/tw.md) |
| `iptables` | `kube-proxy` 實作 `Service` 流量轉送的模式。 | 請依脈絡理解術語，不要以相近概念替代。 | [08](08/tw.md) |
| `IPVS` | Kubernetes v1.35 起逐步淘汰的 `kube-proxy` `Service` 負載平衡模式。 | 請依脈絡理解術語，不要以相近概念替代。 | [08](08/tw.md) |
| `Isolation` | 限制一個主體或 workload 對另一個的影響。 | 範圍比單一網路 segmentation 更廣。 | [05](05/tw.md), [13](13/tw.md) |
| `KCNA` | Kubernetes and Cloud Native Associate，廣泛的 cloud native 入門認證。 | 請依脈絡理解術語，不要以相近概念替代。 | [01](01/tw.md) |
| `KCSA` | Kubernetes and Cloud Native Security Associate，cloud native 與 Kubernetes 安全的概念型認證。 | 請依脈絡理解術語，不要以相近概念替代。 | [01](01/tw.md) |
| `kill chain` | 從初始存取到產生影響的攻擊階段順序模型。 | 請依脈絡理解術語，不要以相近概念替代。 | [15](15/tw.md), [19](19/tw.md) |
| `KMS` | 管理 encryption keys 的服務或 plugin。 | 不是資料 encryption provider 本身。 | [12](12/tw.md) |
| `KMS v2` | API Server 整合 KMS 的目前建議 API；KMS v1 自 v1.28 deprecated，且自 v1.29 預設停用。 | 請依脈絡理解術語，不要以相近概念替代。 | [12](12/tw.md) |
| `kube-apiserver` | control plane 中 API Server 程序的完整名稱。 | 不等同於 kubelet API 或 kube-proxy。 | [07](07/tw.md) |
| `kube-bench` | 將 Kubernetes 元件設定與 CIS Benchmark 檢查比對的工具。 | 不評估應用程式商業邏輯，也不能取代完整稽核。 | [05](05/tw.md), [19](19/tw.md) |
| `Kube-proxy` | 節點元件，設定 kernel 規則 (`iptables`、`nftables`、IPVS) 路由到 `Service`；本身不是 userspace traffic proxy。 | 不會套用 NetworkPolicy，也不親自轉送封包，這由 kernel 執行。 | [08](08/tw.md) |
| `Kubeconfig` | 包含 cluster 位址、受信任 CA 與 client credentials 的檔案。 | 不是不含 secret 的無害設定。 | [09](09/tw.md) |
| `Kubelet` | 透過 container runtime 啟動 Pod 的節點 agent。 | 不是 scheduler。 | [08](08/tw.md) |
| `Kubelet API` | Kubelet 在節點上執行操作與診斷的 HTTPS 介面。 | 請依脈絡理解術語，不要以相近概念替代。 | [08](08/tw.md) |
| `Kubernetes API` | 透過 API Server 管理 cluster 資源的介面。 | 不等同於 kubelet API。 | [07](07/tw.md), [10](10/tw.md) |
| `L3/L4/L7` | 控制層級：IP 網路、傳輸埠與應用協定。 | 請依脈絡理解術語，不要以相近概念替代。 | [13](13/tw.md) |
| `lateral movement` | 攻擊者從遭入侵資源移動到另一資源。 | 請依脈絡理解術語，不要以相近概念替代。 | [15](15/tw.md), [16](16/tw.md) |
| `Least privilege` | 僅授予最小必要權限。 | 不表示所有人都沒有權限。 | [02](02/tw.md), [10](10/tw.md) |
| `level` | 事件中資料的量：`None`、`Metadata`、`Request` 或 `RequestResponse`。 | 請依脈絡理解術語，不要以相近概念替代。 | [14](14/tw.md) |
| `LimitRange` | namespace 中 container 的限制與預設值。 | 不像 ResourceQuota 一樣設定 namespace 總預算。 | [11](11/tw.md), [16](16/tw.md) |
| `Log backend` | 日誌接收端或儲存庫。 | 本身不是所有事件的來源。 | [14](14/tw.md), [18](18/tw.md) |
| `Logging` | 蒐集離散的事件記錄。 | 不等同於 monitoring 或完整 observability。 | [14](14/tw.md), [18](18/tw.md) |
| `MCQ` | Multiple choice question，KCSA 的選擇題考試格式。 | 不同於 CKS 的 hands-on 任務。 | [01](01/tw.md), [20](20/tw.md) |
| `Metric` | 隨時間呈現狀態或行為的數值量測。 | 不包含完整的日誌脈絡。 | [18](18/tw.md) |
| `MITM` | man-in-the-middle，攔截或竄改網路通訊。 | 請依脈絡理解術語，不要以相近概念替代。 | [16](16/tw.md) |
| `MITRE ATT&CK` | 攻擊者行為 tactics 與 techniques 的知識庫。 | 不是 preventive control。 | [15](15/tw.md), [19](19/tw.md) |
| `MITRE ATT&CK for Containers` | 描述 container 環境中攻擊者行為 tactics 與 techniques 的知識庫。 | 請依脈絡理解術語，不要以相近概念替代。 | [15](15/tw.md) |
| `mock exam` | 模擬考試格式與時間限制的練習考試。 | 請依脈絡理解術語，不要以相近概念替代。 | [20](20/tw.md) |
| `Monitoring` | 觀察已知系統指標與閾值。 | 範圍比 observability 窄。 | [18](18/tw.md) |
| `most appropriate` | 指示在語義可接受答案中選擇最直接、最合適的答案。 | 請依脈絡理解術語，不要以相近概念替代。 | [20](20/tw.md) |
| `mTLS` | 對連線雙方進行相互驗證的 TLS。 | 不會定義網路流量 allowlist。 | [18](18/tw.md) |
| `Multi-stage build` | 具有獨立 builder stage 與最小 final stage 的建置方式。 | 請依脈絡理解術語，不要以相近概念替代。 | [06](06/tw.md) |
| `multi-tenancy` | 多個團隊或組織共用一個平台，並分隔存取與資源。 | 請依脈絡理解術語，不要以相近概念替代。 | [13](13/tw.md) |
| `multiple choice` | 有多個答案選項、須選最正確答案的問題。 | 請依脈絡理解術語，不要以相近概念替代。 | [01](01/tw.md) |
| `Mutating admission webhook` | 可在儲存前修改物件的 webhook。 | 不等同於只接受或拒絕的 validating webhook。 | [17](17/tw.md) |
| `MutatingAdmissionPolicy` | 使用 CEL 的內建 declarative admission policy，可修改相符 API 物件且不需獨立 webhook。 | 不等同於外部 mutating admission webhook。 | [17](17/tw.md) |
| `Namespace` | 用於資源、權限與 quota 的 Kubernetes 邏輯範圍。 | 本身不是網路防火牆。 | [05](05/tw.md), [13](13/tw.md) |
| `Network segmentation` | 在 zones 或 workloads 間分隔網路路徑。 | 不等同於整體 isolation。 | [13](13/tw.md), [18](18/tw.md) |
| `NetworkPolicy` | 描述允許 Pod ingress 與 egress 的 API 資源。 | 無法取代 kube-proxy、RBAC 或 TLS。 | [13](13/tw.md) |
| `nftables` | `kube-proxy` 模式，在受支援 Linux 上建議取代 deprecated IPVS。 | 請依脈絡理解術語，不要以相近概念替代。 | [08](08/tw.md) |
| `Node` | Kubernetes 的 worker 或 control-plane 機器。 | 不等同於 Pod。 | [07](07/tw.md), [08](08/tw.md) |
| `Node authorization` | 授權 kubelet API 請求的機制。 | 不是 Node 物件。 | [08](08/tw.md), [10](10/tw.md) |
| `Observability` | 透過 logs、metrics 與 traces 理解系統狀態的能力。 | 不限於單一 monitoring dashboard。 | [18](18/tw.md) |
| `OIDC` | 讓 API Server 信任外部 issuer 的識別協定。 | 不是 Kubernetes 的通用 OAuth authorization。 | [10](10/tw.md) |
| `OPA` | 通用 Policy engine，常透過 Gatekeeper 使用。 | 不是內建 ValidatingAdmissionPolicy。 | [17](17/tw.md) |
| `OpenID Connect` | 作為 OAuth 2.0 上識別層的 OIDC 全名。 | 無法取代 RBAC 決策。 | [10](10/tw.md) |
| `OWASP Kubernetes Top 10` | OWASP (Open Worldwide Application Security Project，開放式 Web 應用程式安全專案) 整理的常見 Kubernetes 風險類別。 | 不是必填 YAML 欄位清單。 | [05](05/tw.md) |
| `PeerAuthentication` | Istio 資源，設定 service mesh 或其部分接收 mTLS 的模式。 | `STRICT` 要求 mTLS，但不能取代 authorization 與 NetworkPolicy。 | [18](18/tw.md) |
| `performance-based` | 評估在環境中完成的實作動作，而非只評估選擇的答案的格式。 | 請依脈絡理解術語，不要以相近概念替代。 | [01](01/tw.md) |
| `persistence` | 攻擊者在初始入口移除後仍能保留存取的能力。 | 請依脈絡理解術語，不要以相近概念替代。 | [16](16/tw.md) |
| `PKI` | key、certificate 與信任鏈的基礎設施。 | 請依脈絡理解術語，不要以相近概念替代。 | [18](18/tw.md) |
| `Pod` | Kubernetes 最小可部署單位，含一個或多個 container。 | 不等同於單一 container。 | [09](09/tw.md), [11](11/tw.md) |
| `Pod Security Admission` | 套用 Pod Security Standards 的內建 admission 機制。 | 不是已移除的 PSP。 | [11](11/tw.md) |
| `Pod Security Standards` | Pod 設定的 privileged、baseline 與 restricted 等級集合。 | 不等同於特定 admission plugin。 | [11](11/tw.md) |
| `Policy` | 定義所需或允許行為的規則。 | 不是每個 policy 都會自行技術性 enforce。 | [13](13/tw.md), [17](17/tw.md) |
| `policy engine` | 將規則套用至 API 物件的機制，通常位於 admission path。 | 請依脈絡理解術語，不要以相近概念替代。 | [05](05/tw.md) |
| `Private key` | 用於簽署或 authentication 的機密密碼學 key。 | 不應與 certificate 一同公開。 | [09](09/tw.md), [18](18/tw.md) |
| `privileged` | 相對於 host 具有非常廣泛權限的 container 模式。 | 請依脈絡理解術語，不要以相近概念替代。 | [09](09/tw.md), [11](11/tw.md) |
| `proctored` | 由監考人監督是否遵守規則的考試。 | 請依脈絡理解術語，不要以相近概念替代。 | [01](01/tw.md) |
| `proctoring` | 依考試供應商規則進行監看的考試程序。 | 請依脈絡理解術語，不要以相近概念替代。 | [20](20/tw.md) |
| `Prometheus` | 蒐集與儲存 metrics 的系統。 | 請依脈絡理解術語，不要以相近概念替代。 | [18](18/tw.md) |
| `Provenance` | 記錄 artifact 來源、原始碼與建立程序的資料。 | 不等同於 digest、signature 或 SBOM。 | [17](17/tw.md), [19](19/tw.md) |
| `PSA` | Pod Security Admission，套用 PSS 的內建 admission controller。 | 請依脈絡理解術語，不要以相近概念替代。 | [11](11/tw.md) |
| `PSP` | Kubernetes v1.25 移除的 PodSecurityPolicy 機制。 | 不是目前替代 PSA 的方案。 | [11](11/tw.md) |
| `PSS` | Pod Security Standards，三個標準 `Pod` 安全設定檔。 | 請依脈絡理解術語，不要以相近概念替代。 | [11](11/tw.md) |
| `Public key` | 用於驗證 signature 或 encryption 的 key pair 公開部分。 | 不應作為 private key 儲存。 | [18](18/tw.md) |
| `RBAC` | 以 roles 及將 subjects 繫結到權限進行 authorization。 | 不是 authentication。 | [10](10/tw.md) |
| `RCE` | remote code execution，透過 vulnerability 遠端執行程式碼。 | 請依脈絡理解術語，不要以相近概念替代。 | [16](16/tw.md) |
| `Registry` | 儲存與提供 container images 的 registry。 | 不會自動證明 image 安全。 | [06](06/tw.md), [17](17/tw.md) |
| `ResourceQuota` | 限制 namespace 中資源的總消耗量。 | 不像 LimitRange 一樣設定 container 邊界。 | [13](13/tw.md), [16](16/tw.md) |
| `restricted` | 供應用 workloads 使用的嚴格 least privilege 設定檔。 | 請依脈絡理解術語，不要以相近概念替代。 | [11](11/tw.md) |
| `Risk` | 不良事件的機率與其後果組合。 | 不等同於 threat 或 vulnerability。 | [15](15/tw.md), [19](19/tw.md) |
| `Role` | namespace 中允許 API 動作的集合。 | 沒有 RoleBinding 不會授予權限。 | [10](10/tw.md) |
| `Role / ClusterRole` | 一個 namespace / cluster 層級的規則集合。 | 請依脈絡理解術語，不要以相近概念替代。 | [10](10/tw.md) |
| `RoleBinding` | 在 namespace 中將 subject 與 Role 或 ClusterRole 繫結。 | 不是 authentication 本身。 | [10](10/tw.md) |
| `RoleBinding / ClusterRoleBinding` | 將 role 繫結至 user、group 或 `ServiceAccount`。 | 請依脈絡理解術語，不要以相近概念替代。 | [10](10/tw.md) |
| `Runtime class` | 選擇用於執行 Pod 的 runtime class。 | 不是 runtime detection。 | [05](05/tw.md), [09](09/tw.md) |
| `Runtime detection` | 偵測 workload 啟動後的程序行為。 | 無法取代 API 請求的 audit logging。 | [16](16/tw.md), [18](18/tw.md) |
| `runtime socket` | client 透過其管理 container runtime 的 Unix socket。 | 請依脈絡理解術語，不要以相近概念替代。 | [08](08/tw.md) |
| `Sandbox` | 執行不受信任 workload 的強化隔離邊界。 | 無法取代 least privilege。 | [05](05/tw.md) |
| `SAST` | 不執行應用程式的靜態程式碼分析。 | 請依脈絡理解術語，不要以相近概念替代。 | [06](06/tw.md) |
| `SBOM` | 軟體 artifact 的 components 與 dependencies 清單。 | 不等同於 signature 或 provenance。 | [06](06/tw.md), [17](17/tw.md) |
| `SCA` | 分析 dependencies 與其已知風險。 | 不等同於 runtime scanner。 | [06](06/tw.md) |
| `Scheduler` | 為新 Pod 選擇 node 的元件。 | 不會在 node 上啟動 containers。 | [07](07/tw.md) |
| `Secret` | 用於少量敏感資料的 Kubernetes API 物件。 | `data` 中的 Base64 不是 encryption。 | [12](12/tw.md) |
| `Secret scanning` | 在程式碼、歷史與 artifacts 中搜尋 credentials 及其他 secrets。 | 請依脈絡理解術語，不要以相近概念替代。 | [06](06/tw.md) |
| `SecurityContext` | 程序或 Pod 的權限與限制設定。 | 無法取代 PSS、RBAC 或 NetworkPolicy。 | [09](09/tw.md), [11](11/tw.md) |
| `Segmentation` | 將系統分為互動受限的 zones。 | 是 isolation 的一種方式，不是完整同義詞。 | [13](13/tw.md), [15](15/tw.md) |
| `Service identity` | 服務 identity：元件或 workload 存取 API 所用的帳戶。 | 不是人類 operator 的 identity。 | [07](07/tw.md) |
| `Service mesh` | 處理 service connectivity、identity 且常包含 mTLS 的基礎設施層。 | 無法取代 NetworkPolicy。 | [18](18/tw.md) |
| `ServiceAccount` | Pod 中程序使用的 Kubernetes identity。 | 沒有 RBAC 不會取得權限。 | [10](10/tw.md), [12](12/tw.md) |
| `Shared responsibility` | provider 與 customer 間的防護責任分配。 | 不表示 provider 會保護 customer workload。 | [04](04/tw.md) |
| `SIEM` | 集中化與關聯 security 事件的系統。 | 不是 API Server audit 事件來源。 | [14](14/tw.md), [18](18/tw.md) |
| `Signature` | 將資料與簽署 key 連結的密碼學證明。 | 不等同於 digest、SBOM 或 provenance。 | [06](06/tw.md), [17](17/tw.md) |
| `SLSA` | 具獨立 Build 與 Source tracks 的 supply chain 要求 framework。 | 不是 reproducible build 的通稱。 | [17](17/tw.md), [19](19/tw.md) |
| `SLSA v1.2` | 具獨立 Build 與 Source tracks 的要求 framework，等級須連同 track 指出。 | 請依脈絡理解術語，不要以相近概念替代。 | [17](17/tw.md), [19](19/tw.md) |
| `snapshot` | 特定時間點 `etcd` 狀態的一致性 Backup。 | 請依脈絡理解術語，不要以相近概念替代。 | [07](07/tw.md) |
| `SOC 2` | 依 Trust Services Criteria 評估服務組織 controls。 | 不是 Kubernetes security standard。 | [19](19/tw.md) |
| `soft multi-tenancy` | 在共用 cluster 中以邏輯 controls 分隔受信任團隊。 | 請依脈絡理解術語，不要以相近概念替代。 | [05](05/tw.md) |
| `Software supply chain` | 從 code、dependencies、build 到 runtime 的交付路徑。 | 不限於 container registry。 | [06](06/tw.md), [17](17/tw.md) |
| `SPIFFE` | 分散式系統的 workload identity 標準。 | 本身不是 TLS certificate。 | [18](18/tw.md) |
| `stage` | 請求處理時刻：`RequestReceived`、`ResponseStarted`、`ResponseComplete` 或 `Panic`。 | 請依脈絡理解術語，不要以相近概念替代。 | [14](14/tw.md) |
| `STRIDE` | 依六種類別建模 threats 的 framework。 | 不是實際攻擊的日誌。 | [15](15/tw.md), [19](19/tw.md) |
| `Subject` | 請求以其身分執行的 user、group 或 ServiceAccount。 | 不等同於 Role 或 permission。 | [10](10/tw.md) |
| `Supply chain` | 建立及交付軟體 artifact 的鏈路。 | 不等同於單一 build 階段。 | [17](17/tw.md), [19](19/tw.md) |
| `Syscall` | 程序對 OS kernel 進行的 system call。 | 不是 Kubernetes API 呼叫。 | [16](16/tw.md), [18](18/tw.md) |
| `Tag` | 對 image version 的人類可讀參照。 | 可能是 mutable，且不等同於 digest。 | [06](06/tw.md) |
| `Threat` | 不良事件的可能成因或情境。 | 不等同於 vulnerability 或已評估 risk。 | [15](15/tw.md), [16](16/tw.md) |
| `Threat model` | 說明系統 assets、boundaries、flows 與 threats 的資料。 | 不是 CVE 清單。 | [15](15/tw.md), [19](19/tw.md) |
| `TLS` | 加密與驗證連線的協定。 | 無法取代 NetworkPolicy 或 authorization。 | [07](07/tw.md), [18](18/tw.md) |
| `TLS termination` | 元件終止 TLS 並解密連線的位置。 | 請依脈絡理解術語，不要以相近概念替代。 | [18](18/tw.md) |
| `Token` | 用於 authentication 時出示的 credentials。 | 不等同於自動受限的 RBAC 存取。 | [10](10/tw.md) |
| `Trace` | 請求經過分散式 services 的關聯路徑。 | 不等同於單筆 log 記錄。 | [18](18/tw.md) |
| `Trust boundary` | 信任、權限或資料控制變化的位置。 | 不一定與 namespace 重合。 | [15](15/tw.md) |
| `Trusted image` | 具有可驗證來源與一組信任 controls 的 image。 | 請依脈絡理解術語，不要以相近概念替代。 | [06](06/tw.md) |
| `Trusted registry` | policy 允許供應 images 的 Registry。 | 不證明 image 沒有 CVE。 | [06](06/tw.md), [17](17/tw.md) |
| `ValidatingAdmissionPolicy` | 使用 CEL 驗證 API 物件的內建 declarative admission policy，為 cluster-scoped，並透過獨立 `ValidatingAdmissionPolicyBinding` 套用。 | 不存在於「某個 namespace」中，namespace 範圍由 binding/`matchResources` 指定。 | [17](17/tw.md) |
| `version-light` | 考試以核心概念而非綁定單一 Kubernetes 版本為重的特性。 | 請依脈絡理解術語，不要以相近概念替代。 | [01](01/tw.md) |
| `Vulnerability` | 可由 threat 或 exploit 利用的弱點。 | 不等同於 threat 或 risk。 | [06](06/tw.md), [16](16/tw.md) |
| `Vulnerability scanner` | 依 component 資料搜尋已知 vulnerabilities 的工具。 | 不會預防 runtime 行為。 | [06](06/tw.md), [17](17/tw.md) |
| `warn` | 向 client 顯示警告但不拒絕請求的 PSA 模式。 | 請依脈絡理解術語，不要以相近概念替代。 | [11](11/tw.md) |
| `Webhook` | Kubernetes 或其他元件呼叫的 HTTP handler。 | 不是每個 webhook 都與 admission 有關。 | [10](10/tw.md), [17](17/tw.md) |
| `webhook backend` | 將 audit 事件傳至 HTTPS collector 或 SIEM 的 backend。 | 請依脈絡理解術語，不要以相近概念替代。 | [14](14/tw.md) |
| `Workload` | 執行中的應用程式及管理它的 Kubernetes 資源。 | 不等同於單一 container image。 | [03](03/tw.md), [09](09/tw.md) |
| `Zero trust` | 不對網路、identity 或位置給予隱含信任的方法。 | 不表示禁止所有互動。 | [02](02/tw.md), [18](18/tw.md) |
| `信任邊界` | 不同信任等級的參與者或脈絡之間的轉換點。 | 請依脈絡理解術語，不要以相近概念替代。 | [15](15/tw.md) |
| `威脅模型` | 對系統 assets、participants、flows、trust boundaries、threats 與 controls 的說明。 | 請依脈絡理解術語，不要以相近概念替代。 | [15](15/tw.md) |
| `資料流` | 元件間的請求、狀態或資料傳遞。 | 請依脈絡理解術語，不要以相近概念替代。 | [15](15/tw.md) |
| `服務身分 (service identity)` | 元件存取 Kubernetes API 所用的服務帳戶。 | 請依脈絡理解術語，不要以相近概念替代。 | [07](07/tw.md) |

## 易混淆術語

- [Authentication](10/tw.md) 用於建立 identity，[authorization](10/tw.md) 用於檢查權限，而 [admission control](11/tw.md) 在前兩個階段後評估物件是否可接受。
- [Audit logging](14/tw.md) 處理 API 事件，而 [runtime detection](18/tw.md) 處理啟動後的程序行為。
- [Encryption](12/tw.md) 需要 key 來保護資料，[Base64](12/tw.md) 僅是可逆 encoding。
- [Digest](06/tw.md) 固定內容，[signature](17/tw.md) 將資料與 key 連結，[SBOM](17/tw.md) 列出 components，而 [provenance](17/tw.md) 說明來源。
- [Isolation](13/tw.md) 涵蓋多種邊界，[segmentation](13/tw.md) 將其分隔成 zones 與路徑。
- [Control](05/tw.md) 降低風險，[framework](19/tw.md) 協助選擇與評估 controls。
- [Vulnerability](16/tw.md) 是弱點，[threat](15/tw.md) 是可能情境，[risk](19/tw.md) 是機率與後果的評估。
- [Logging](18/tw.md) 保存事件，[monitoring](18/tw.md) 追蹤已知指標，[observability](18/tw.md) 讓人從多種訊號解釋狀態。
- [CIA triad](02/tw.md) 結合 [confidentiality](12/tw.md)、[integrity](19/tw.md) 與 [availability](16/tw.md)。

[目錄與準備路線](README_TW.md)
