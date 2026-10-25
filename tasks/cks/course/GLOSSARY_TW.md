[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [日本語版](GLOSSARY_JP.md)

# CKS 課程詞彙表

[← 課程內容](README_TW.md) · [速查表](CHEATSHEET_TW.md) · [故障排除索引 (RU)](TROUBLESHOOTING_INDEX_RU.md)

依英文字母順序排列的 CKS 術語參考表，保留英文術語並以繁體中文說明。「章節」連結至詳細解說；「實驗/題目」僅列出已確認的實作對應，純理論術語則留白。現成的程式碼片段請見[速查表](CHEATSHEET_TW.md)。

| 術語 | 說明 | 章節 | 實驗/題目 |
|--------|----------|-------|--------------|
| **4C** | 用於評估 Kubernetes 安全性的雲端、叢集、容器和程式碼層模型。 | [02](02/tw.md) | |
| **Admission control** | 在身份驗證和授權之後、在物件儲存在 etcd 之前，API 伺服器請求處理階段。 | [01](01/tw.md), [20](20/tw.md) | labs/107 (題目 6) |
| **Admission policy** | 允許、修改或拒絕 Kubernetes API 請求的規則。 | [01](01/tw.md), [20](20/tw.md) | labs/107 (題目 6), labs/108 |
| **Admission scan** | 使用掃描結果或關聯證明檢查工作負載建立。 | [28](28/tw.md) | |
| **Admission verification** | 在 API 伺服器保留 Pod 之前，強制驗證影像來源或簽章。 | [26](26/tw.md) | labs/111 (題目 9a) |
| **aescbc** | 使用帶有 PKCS#7 填充的 AES-CBC 的 Kubernetes API 資料加密提供者；它的金鑰儲存在受保護的配置中。它沒有內建的密文驗證（沒有 HMAC/AEAD），並且與 `aesgcm` 或 KMS v2 相比被認為是弱/遺留選項，因為 CBC 容易受到 padding-oracle 攻擊。 | [21](21/tw.md) | labs/109 (題目 2) |
| **aesgcm** | 用於 API 資料加密的 AES-GCM AEAD 提供者；鑰匙需要定期輪換。 | [21](21/tw.md) | |
| **allow-list / allowlist** | 允許的操作、來源或目的地的明確清單；任何未列出的內容都會被拒絕。 | [12](12/tw.md), [15](15/tw.md), [17](17/tw.md) | labs/112 (題目 9) |
| **anonymous authentication** | 將沒有憑證的請求對應到 `system:anonymous`；通常對於 API 和 kubelet 停用。 | [12](12/tw.md) | labs/104 (題目 5) |
| **AppArmor** | 基於路徑的 Linux MAC，將進程操作限制為設定檔允許的操作。 | [03](03/tw.md), [16](16/tw.md) | labs/106 (題目 1-2) |
| **apparmor_parser** | 用於檢查、載入、取代和卸載 AppArmor 設定檔的實用程式。 | [16](16/tw.md) | labs/106 (題目 1) |
| **Artifact** | 建構產物，例如 OCI 映像、SBOM、chart 或 provenance 資訊。 | [25](25/tw.md) | labs/111 |
| **Artifact repository** | 受控的產物儲存空間：registry、套件儲存庫或 chart 儲存庫。 | [25](25/tw.md) | |
| **attack surface** | 可能發生攻擊或錯誤配置的所有介面、元件和入口點。 | [02](02/tw.md), [14](14/tw.md), [24](24/tw.md) | labs/105 |
| **Attribution** | 將事件與進程、容器、Pod、身分、節點和時間相關聯。 | [30](30/tw.md) | labs/112 (題目 6) |
| **audience** | ServiceAccount 代幣的預期接收者；服務應該只接受具有自己受眾的代幣。 | [11](11/tw.md) | labs/104 (題目 2) |
| **audit / enforce / warn** | 獨立的 PSA 模式：記錄違規、拒絕 Pod 或回傳警告。 | [19](19/tw.md), [31](31/tw.md) | labs/107 (題目 1, 3-4) |
| **audit backend** | 本機檔案後端或 Webhook 後端接收審核原則選擇的事件。 | [32](32/tw.md) | labs/112 (題目 4, 8) |
| **audit event** | 一個 Kubernetes API 請求的 API 伺服器記錄。 | [32](32/tw.md) | labs/112 (題目 4) |
| **audit policy** | 定義審核層級和排除的事件階段的有序規則。 | [32](32/tw.md) | labs/112 (題目 4) |
| **auditID** | 連結單一 API 請求的所有審核階段的識別碼。 | [32](32/tw.md) | |
| **Base image** | `FROM` 指令中的映像提供建置階段的初始檔案系統。 | [24](24/tw.md) | labs/111 (題目 3) |
| **Bound ServiceAccount token** | 綁定到 ServiceAccount 和 Pod 的短期 TokenRequest API 代幣。 | [11](11/tw.md) | labs/104 (題目 2) |
| **BPF filter** | 由核心為 seccomp 過濾模式下的系統呼叫所執行的過濾程式。 | [17](17/tw.md) | labs/106 (題目 4-5) |
| **break-glass access** | 針對緊急情況或事件控制臨時特權存取。 | [10](10/tw.md), [15](15/tw.md) | |
| **Build context** | 發送給建構器的檔案； `.dockerignore` 減少了該集合。 | [24](24/tw.md) | |
| **CAP_SYS_ADMIN** | 過於寬泛的 Linux 功能對於一般工作負載來說是危險的。 | [03](03/tw.md) | labs/106 (題目 5) |
| **capability** | 從 root 權力中提取的個人 Linux 特權；安全基線會刪除 `ALL` 並僅恢復所需的內容。 | [03](03/tw.md), [18](18/tw.md) | labs/107 (題目 2) |
| **CEL** | 通用表達式語言，由內建 ValidatingAdmissionPolicy 使用。 | [20](20/tw.md) | labs/107 (題目 6), labs/108, labs/111 (題目 9a), labs/112 (題目 9) |
| **cgroup** | 對 CPU、記憶體、PIDs 和其他資源進行限制和會計的進程組。 | [03](03/tw.md) | |
| **CI gate** | 強制檢查，在非零退出代碼上阻塞下一個管道階段。 | [27](27/tw.md), [28](28/tw.md) | |
| **Cilium** | 基於 eBPF 的 Kubernetes CNI 和安全平台。 | [06](06/tw.md), [23](23/tw.md) | labs/102, labs/110 (題目 4) |
| **CiliumClusterwideNetworkPolicy (CCNP)** | 集群範圍的 Cilium 策略；其廣泛的範圍需要特別謹慎的推出。 | [06](06/tw.md) | |
| **CiliumNetworkPolicy (CNP)** | 具有 L3/L4/L7 規則的命名空間 Cilium 策略資源。 | [06](06/tw.md) | labs/102 (題目 3) |
| **cipher suite** | 一套與憑證和客戶端相容的TLS密碼演算法。 | [09](09/tw.md) | labs/103 (題目 5) |
| **CIS Kubernetes Benchmark** | CIS 針對 Kubernetes 元件和節點安全配置的建議。 | [01](01/tw.md), [07](07/tw.md) | labs/103 (題目 1, 7) |
| **CKS** | 認證Kubernetes安全專家，實用的Kubernetes安全認證。 | [01](01/tw.md), [33](33/tw.md) | |
| **Clair** | 基於服務的容器鏡像漏洞掃描器和索引器。 | [28](28/tw.md) | |
| **complain** | AppArmor 模式，記錄策略違規行為而不阻止它們。 | [16](16/tw.md) | |
| **condition** | 事件欄位的布林 Falco 表達式，用於決定是否觸發規則。 | [29](29/tw.md) | labs/112 (題目 3, 7, 9) |
| **Constraint** | 具有參數、匹配範圍和操作的 Gatekeeper 模板實例。 | [20](20/tw.md) | |
| **ConstraintTemplate** | 新 Gatekeeper 約束類型的 Rego 範本和參數架構。 | [20](20/tw.md) | |
| **container escape** | 逃避預期的容器隔離以存取節點或其他租戶資源。 | [03](03/tw.md) | |
| **Container runtime sandbox** | 在工作負載和主機核心之間新增隔離邊界的執行時間。 | [22](22/tw.md) | labs/110 (題目 1-3) |
| **Confidential computing / TEE** | 硬件隔离的 CPU 区域（Intel SGX、AMD SEV）甚至可以保护内存数据免受虚拟机管理程序和云提供商的侵害； Kubernetes通过特殊的`RuntimeClass`（机密容器）公开它，而硬件保证位于Kubernetes API以外。 | [30](30/tw.md) | |
| **context** | kubeconfig 中叢集、使用者和命名空間的命名組合。 | [33](33/tw.md) | |
| **Correlation** | 將不同來源的事件連結到單一事件時間軸。 | [30](30/tw.md) | labs/112 (題目 6) |
| **Cosign** | 用於簽署和驗證 OCI 工件的 Sigstore 工具。 | [26](26/tw.md) | labs/111 (題目 7, 9a, 9c) |
| **CRI** | 容器運行時介面； `crictl` 透過 CRI 套接字存取運行時。 | [14](14/tw.md), [30](30/tw.md) | labs/112 (題目 6) |
| **CRI socket** | kubelet - 運行時通訊端點，例如 `/run/containerd/containerd.sock`。 | [14](14/tw.md) | |
| **CVE** | 公開已知漏洞的識別碼。 | [13](13/tw.md), [28](28/tw.md) | labs/111 (題目 1) |
| **CycloneDX** | 用於 SBOM 中的元件清單和安全分析的 OWASP 格式。 | [25](25/tw.md), [28](28/tw.md) | labs/111 (題目 7) |
| **daemon.json** | Docker 守護程式設定文件，通常為 `/etc/docker/daemon.json`。 | [14](14/tw.md) | |
| **DaemonSet** | Kubernetes 工作負載在每個選定節點上維護代理 Pod。 | [29](29/tw.md) | |
| **defense in depth** | 獨立的保護層可減少一個控制失敗的影響。 | [01](01/tw.md), [02](02/tw.md) | labs/104 (題目 3) |
| **deny-list** | 其預設操作允許系統呼叫而拒絕特定係統呼叫的策略。 | [17](17/tw.md) | |
| **Digest** | 與可變標籤不同，特定影像清單或工件的不可變 SHA-256 識別碼。 | [09](09/tw.md), [24](24/tw.md), [25](25/tw.md), [26](26/tw.md) | labs/111 (題目 3-5, 9c) |
| **distroless** | 沒有套件管理器並且通常沒有 shell 的最小運行時映像。 | [24](24/tw.md), [31](31/tw.md) | labs/111 (題目 7) |
| **docker group** | 具有 Docker 套接字存取權限的群組應視為與 root 等效。 | [14](14/tw.md) | labs/105 (題目 6) |
| **Docker socket** | `/var/run/docker.sock`，本地Docker守護程式API；存取權限幾乎相當於主機上的root。 | [14](14/tw.md) | labs/105 (題目 6) |
| **drop-in** | 擴展基本配置的單獨配置文件，例如 systemd 或 SSH。 | [15](15/tw.md) | |
| **eBPF** | 針對受限程式的 Linux 核心機制； Cilium 將其用於資料路徑，Falco 將其用於事件。 | [06](06/tw.md), [29](29/tw.md) | labs/112 (題目 1) |
| **egress policy** | 指定允許的出站 Pod 連接的 NetworkPolicy。 | [04](04/tw.md), [05](05/tw.md) | labs/101 (題目 2, 4, 6) |
| **encryption at rest** | 將儲存在 etcd、磁碟、快照和備份中的資料加密。 | [21](21/tw.md) | labs/109 |
| **EncryptionConfiguration** | kube-apiserver 讀取的加密提供者配置。 | [21](21/tw.md) | labs/109 (題目 2) |
| **enforce** | 實際上阻止策略違規的 AppArmor 或 PSA 模式。 | [16](16/tw.md), [19](19/tw.md) | labs/106 (題目 1), labs/107 (題目 1) |
| **Entity** | 預先定義的 Cilium 位址組，例如 `world`、`cluster` 或 `host`。 | [06](06/tw.md) | |
| **envelope encryption** | 以資料加密金鑰（DEK）加密物件，再以外部金鑰加密金鑰（KEK）保護 DEK。 | [21](21/tw.md) | |
| **evidence** | 確認結果的可驗證工件：API 物件、日誌、設定檔、掃描器報告或網路測試。 | [33](33/tw.md) | |
| **exemption** | 針對可信任命名空間、使用者名稱或 RuntimeClass 的狹窄 PSA 繞過；它不授予 RBAC 權限。 | [19](19/tw.md) | |
| **Exfiltration** | 未經授權跨信任邊界傳輸資料。 | [02](02/tw.md), [30](30/tw.md) | |
| **failurePolicy** | Webhook/政策無法使用或發生錯誤時的 API 伺服器操作：通常為 `Fail` 或 `Ignore`。 | [20](20/tw.md) | labs/107 (題目 6) |
| **Falco** | 使用核心事件和容器/Kubernetes 元資料的運行時安全事件規則引擎。 | [29](29/tw.md), [30](30/tw.md) | labs/112 (題目 1-3, 6-7, 9) |
| **Falco rule override** | 對 Falco 規則條件或例外進行本地更改，無需編輯供應商規則集。 | [29](29/tw.md), [30](30/tw.md) | labs/112 (題目 7) |
| **falco_rules.local.yaml** | 本地覆蓋和自訂 Falco 規則的首選檔案。 | [29](29/tw.md), [30](30/tw.md) | labs/112 (題目 3, 7, 9) |
| **False positive** | 不適用於特定資源的發現；它需要一個狹窄的、有記錄的例外。 | [27](27/tw.md) | |
| **fixed version** | 供應商修復了 CVE 的元件版本。 | [13](13/tw.md), [28](28/tw.md) | |
| **footprint** | 增加節點攻擊面的套件、進程、連接埠、套接字和配置。 | [14](14/tw.md) | labs/105 (題目 1-2) |
| **Gatekeeper** | 基於 OPA 的 Kubernetes 策略引擎，具有 `ConstraintTemplate` 和 `Constraint` 車型。 | [20](20/tw.md), [26](26/tw.md) | |
| **Grype** | 用於容器映像和 SBOM 的 Anchore 生態系統掃描器。 | [28](28/tw.md) | |
| **gVisor** | 具有用戶空間核心的沙箱運行時；其 OCI 運行時和 CRI 處理程序通常稱為 `runsc`。 | [03](03/tw.md), [22](22/tw.md) | labs/110 (題目 1-3) |
| **handler** | CRI配置中的執行時間名稱；它必須符合 `RuntimeClass.spec.handler`。 | [22](22/tw.md) | labs/110 (題目 1) |
| **Hardware root of trust** | 植根於實體設備（TPM/vTPM）的加密信任鏈，用於驗證節點引導鏈完整性（BIOS/UEFI→引導程式→核心→執行時間）；驗證位於 Kubernetes API 之外。 | [30](30/tw.md) | |
| **host endpoint** | 節點網路端點，而不是 CNI 資料平面中的普通 Pod。 | [05](05/tw.md) | |
| **host firewall** | 節點本身的流量過濾，例如使用 `ufw`、`iptables` 或 `nftables`。 | [15](15/tw.md) | labs/105 (題目 3) |
| **host namespace** | Pod 透過 `hostPID`、`hostNetwork` 或 `hostIPC` 共享的節點命名空間。 | [18](18/tw.md) | labs/101 (題目 7) |
| **Host PID** | 節點 PID 命名空間中的容器流程 PID，是 `/proc` 和 `strace` 所需的。 | [30](30/tw.md) | labs/112 (題目 6) |
| **HSM (Hardware Security Module)** | 防止軟體提取私鑰的實體金鑰儲存裝置（例如 kube-apiserver CA 私鑰或 KMS 主金鑰）。 | [21](21/tw.md), [30](30/tw.md) | |
| **Hubble** | Cilium 網路流量的可觀測性。 | [06](06/tw.md) | labs/102 (題目 5) |
| **identity** | 標籤派生的 Cilium 端點標識符；與 `identity` 提供者不同。 | [06](06/tw.md), [21](21/tw.md) | labs/102 |
| **ImagePolicyWebhook** | 准入插件，透過 `ImageReview` 將影像決策委託給外部後端。 | [26](26/tw.md) | |
| **IMDS** | 實例元資料 Service，雲端提供者的實例元資料端點。 | [05](05/tw.md) | labs/101 (題目 5) |
| **IMDSv2** | AWS IMDS 變體需要元資料請求的臨時令牌。 | [05](05/tw.md) | |
| **Immutable infrastructure** | 一種用新的經過驗證的版本替換生產工件而不是在運行時更改它的方法。 | [02](02/tw.md), [31](31/tw.md) | |
| **include** | 載入外部檔案的指令：檢查設定中的 SSH `Include`、AppArmor `#include` 或 `include:`。 | [15](15/tw.md), [16](16/tw.md), [27](27/tw.md) | labs/105 (題目 5) |
| **Ingress** | 進入 Pod 或 Kubernetes API 物件的流量將外部 HTTP/HTTPS 路由到 Service；上下文決定意義。 | [04](04/tw.md), [08](08/tw.md) | labs/101 (題目 2), labs/103 (題目 4) |
| **IngressClass** | 選擇 Ingress 實現，例如 NGINX Ingress 控制器。 | [08](08/tw.md) | |
| **Inner packet** | 加密前或解密後可見的原始 Pod-to-Pod 流程。 | [23](23/tw.md) | labs/110 (題目 5) |
| **ipBlock** | CIDR 或單一 IP 的入口/出口規則； `except` 不包括位址和子網路。 | [04](04/tw.md), [05](05/tw.md) | labs/101 (題目 6) |
| **IPsec ESP** | IP 等級受保護的有效負載提供安全關聯之間的機密性和完整性。 | [23](23/tw.md) | |
| **Kata Containers** | 在具有來賓核心的輕量級 VM 中啟動 Pod 沙箱的運行時。 | [03](03/tw.md), [22](22/tw.md) | |
| **KEK/DEK** | 信封加密中的密鑰加密密鑰和資料加密密鑰。 | [21](21/tw.md) | |
| **kernel module** | 可載入核心模組，Falco 捕獲事件的一種方式。 | [29](29/tw.md) | labs/105 (題目 7) |
| **Keyless signing** | 在 OIDC 驗證後使用短期憑證而不是持久性本地簽章金鑰進行簽章。 | [26](26/tw.md) | labs/111 (題目 7) |
| **Kill chain** | 從初始訪問到目標（例如滲透）的攻擊階段順序。 | [02](02/tw.md), [30](30/tw.md) | labs/112 (題目 6) |
| **kube-bench** | 使用 CIS Kubernetes 基準設定檔的設定檢查工具。 | [07](07/tw.md), [33](33/tw.md) | labs/103 (題目 1, 7) |
| **kube-linter** | Kubernetes YAML 和 Helm 圖表 linter 具有最佳實務檢查。 | [27](27/tw.md) | labs/111 (題目 2) |
| **kubelet** | Kubernetes節點代理程式；其安全端點通常偵聽連接埠 `10250`。 | [05](05/tw.md), [07](07/tw.md) | labs/103 (題目 2), labs/105 (題目 8) |
| **kubesec** | Kubernetes 清單掃描器報告安全評分和控制。 | [27](27/tw.md) | labs/111 (題目 2, 4) |
| **Kyverno** | 具有 YAML 規則的 Kubernetes 原生策略引擎：`validate`、`mutate`、`generate` 和 `verifyImages`。 | [20](20/tw.md), [26](26/tw.md), [31](31/tw.md) | labs/108, labs/111 (題目 9a), labs/112 (題目 9) |
| **L3/L4** | Cilium 策略中的網路層和傳輸協定/連接埠。 | [06](06/tw.md) | labs/102 (題目 2) |
| **L7** | 協定層，例如 HTTP 方法/路徑或 DNS（不建議使用 Cilium Kafka 過濾）。 | [06](06/tw.md) | labs/102 (題目 3) |
| **lateral movement** | 攻擊者從受損的工作負載轉移到其他系統、資料或身分。 | [02](02/tw.md), [04](04/tw.md) | |
| **least privilege** | 僅授予身分最低限度的必要權限、範圍和持續時間。 | [02](02/tw.md), [10](10/tw.md), [15](15/tw.md) | labs/104 (題目 1) |
| **legacy annotation** | 過時的 AppArmor beta 註釋，可讀取以進行遷移，但不用於新的 Pods。 | [16](16/tw.md) | |
| **level** | 審核事件中的資料詳細資料：`None`、`Metadata`、`Request` 或 `RequestResponse`。 | [32](32/tw.md) | labs/112 (題目 4) |
| **Linkerd identity** | Linkerd mTLS 標識，通常源自 ServiceAccount。 | [23](23/tw.md) | |
| **live-restore** | Docker 模式在守護程式重新啟動時保持容器運作。 | [14](14/tw.md) | |
| **Localhost** | 節點上預先載入的 AppArmor/seccomp 設定檔的 Kubernetes 類型。 | [16](16/tw.md), [17](17/tw.md) | labs/106 (題目 2, 4) |
| **localhostProfile** | 相對於 kubelet seccomp 根的 JSON 設定檔路徑。 | [17](17/tw.md) | labs/106 (題目 4) |
| **MAC** | 強制存取控制，除了 UID/GID 和模式位元之外還強制執行的存取策略。 | [03](03/tw.md), [16](16/tw.md) | |
| **macro** | Falco 條件的可重複使用命名片段。 | [29](29/tw.md) | labs/112 (題目 7) |
| **mTLS** | TLS，其中用戶端和伺服器均提供憑證。 | [23](23/tw.md) | labs/110 (題目 6) |
| **Multi-stage build** | 具有透過 `COPY --from=` 連接的單獨建置和運行時階段的 Dockerfile。 | [24](24/tw.md) | |
| **Mutating admission webhook** | 在驗證之前新增或修改物件的 Webhook。 | [20](20/tw.md) | labs/108 (題目 5) |
| **namespace** | 進程組的核心資源的隔離視圖；與 Kubernetes 命名空間不同。 | [03](03/tw.md) | labs/106 (題目 6) |
| **namespaceSelector** | 透過跨命名空間 NetworkPolicy 規則的標籤選擇 Kubernetes 命名空間。 | [04](04/tw.md) | labs/101 (題目 6) |
| **network namespace** | 進程的介面、路由和網路堆疊的隔離。 | [03](03/tw.md) | |
| **no_new_privs** | 透過 `exec` 阻止額外特權的核心標誌；由 `allowPrivilegeEscalation: false` 啟用。 | [18](18/tw.md) | |
| **Node authorizer** | 對所需的 Node 和 Pod 物件進行 kubelet 身分操作的授權者。 | [12](12/tw.md) | |
| **Node encryption** | 保護節點間流量；不等同於特定工作負載的識別。 | [23](23/tw.md) | labs/110 (題目 4-5) |
| **NodeRestriction** | 准入插件進一步將 kubelet 限制為其節點以及分配給它的 Pods。 | [12](12/tw.md) | |
| **Notary Project / Notation** | 具有 X.509 信任策略的 OCI 簽章生態系統； Kubernetes 強制執行需要准入整合。 | [26](26/tw.md) | |
| **OCI** | 註冊表和簽名工具使用的容器映像和工件格式的開放標準。 | [25](25/tw.md), [26](26/tw.md) | labs/111 |
| **OPA** | 開啟策略代理，執行聲明性 Rego 規則的策略引擎。 | [20](20/tw.md), [27](27/tw.md) | |
| **Outer packet** | 實體網路上節點 IP 之間的加密資料包。 | [23](23/tw.md) | labs/110 (題目 5) |
| **partial credit** | 獨立、正確完成任務部分的榮譽。 | [33](33/tw.md) | |
| **PeerAuthentication** | Istio 入站 mTLS 策略； `STRICT` 拒絕明文。 | [23](23/tw.md) | labs/110 (題目 6) |
| **Performance-based** | 一種考試形式，要求在工作環境中獲得結果，而不是選擇測試答案。 | [01](01/tw.md), [33](33/tw.md) | |
| **PID namespace** | 進程列表和進程PIDs的隔離。 | [03](03/tw.md) | |
| **Pod UID** | 特定 Pod 實例的不可變 UID，比其關聯名稱更可靠。 | [30](30/tw.md) | |
| **podSelector** | 透過 NetworkPolicy 命名空間內的標籤選擇 Pods。 | [04](04/tw.md) | labs/101 (題目 2, 6) |
| **PolicyReport** | 當策略引擎安裝此 API 時，策略檢查結果的報告。 | [31](31/tw.md) | |
| **private key** | 非對稱金鑰對的秘密部分；依據 TLS 身分協定/工具（第 07-08 章）或 Cosign 簽章金鑰（實驗 111）使用。兩者都需要限制訪問，通常為 `0600`。 | [07](07/tw.md), [08](08/tw.md) | labs/111 (題目 9a) |
| **profiling** | 製程效能診斷終點；除非需要，否則使用 `--profiling=false` 停用。 | [07](07/tw.md), [12](12/tw.md) | labs/103 (題目 3) |
| **projected volume** | 將代幣、ConfigMaps、向下的 API 和其他來源組合到 Pod 檔案中的磁碟區。 | [11](11/tw.md) | labs/104 (題目 2) |
| **provenance** | 描述產物來源、輸入、建構器與建構流程的中繼資料（attestation）。可驗證的來源不同於單純的簽章驗證：`cosign sign`/`verify` 證明簽章或身分，不證明完整建構歷程；Sigstore 使用 `cosign attest`/`verify-attestation` 處理 provenance。 | [09](09/tw.md), [25](25/tw.md), [26](26/tw.md) | |
| **provider** | 一種對指定 API 資源進行加密和解密的機制。 | [21](21/tw.md) | labs/109 (題目 2) |
| **PSA** | Pod 安全准入，PSS 內建的驗證准入控制器。 | [19](19/tw.md), [31](31/tw.md) | labs/107 (題目 1, 3-4) |
| **PSP** | PodSecurityPolicy，PSA 的前身在 Kubernetes 1.25 中刪除。 | [19](19/tw.md) | |
| **PSS** | Pod 安全標準：預先定義的 `privileged`、`baseline` 和 `restricted` 設定檔。 | [19](19/tw.md) | labs/107 |
| **purl** | 包 URL，包標識符，包括其生態系統和版本。 | [25](25/tw.md) | |
| **re-encryption** | 透過新的加密提供者或金鑰重寫舊的 API 物件。 | [21](21/tw.md) | labs/109 (題目 2) |
| **read-only kubelet port** | 必須使用 `0` 停用舊版未經驗證的 kubelet 連接埠。 | [07](07/tw.md), [09](09/tw.md), [12](12/tw.md) | labs/103 (題目 2) |
| **read-only root filesystem** | 防止影像圖層變化的模式；允許的寫入寫入磁碟區。 | [18](18/tw.md), [31](31/tw.md), [33](33/tw.md) | labs/107 (題目 5), labs/112 (題目 5) |
| **Registry allowlist** | 只允許明確列出的 registry/repository 身分所提供的映像。必須明確選擇完全相符或前綴比對：實驗 112 顯示，前綴/`startsWith` 可能放行相似名稱（允許 `library/busybox` 時誤放 `library/busybox-evil`），因此採用完全相符比對。 | [26](26/tw.md) | labs/112 (題目 9) |
| **release cadence** | 次要版本和補丁版本的頻率。 | [13](13/tw.md) | |
| **remediation** | 透過更新工件、相依性或基礎映像並驗證結果來消除風險。 | [28](28/tw.md) | |
| **Rendered manifest** | `helm template`或`kustomize build`之後的最終YAML，在部署前進行分析。 | [27](27/tw.md) | |
| **RoleBinding** | Role 或 ClusterRole 到主題的命名空間綁定，例如 ServiceAccount。 | [10](10/tw.md), [11](11/tw.md) | labs/104 (題目 1) |
| **Rootless Podman** | Podman 模式，其中普通使用者執行建置/運行，而不是 root 守護程式。 | [24](24/tw.md) | |
| **rotation** | 按大小、計數或期限重新命名和刪除舊日誌檔案。 | [21](21/tw.md), [32](32/tw.md) | labs/112 (題目 4) |
| **rule** | 名為 Falco 的偵測器，具有條件、輸出和優先權。 | [29](29/tw.md) | labs/112 (題目 3, 7, 9) |
| **runtime detection** | 使用系統呼叫/eBPF 和運行時元資料檢測正在運行的進程的可疑行為。 | [01](01/tw.md), [29](29/tw.md), [30](30/tw.md) | labs/112 |
| **Runtime mutation** | 更改正在運行的容器的檔案系統或配置。 | [31](31/tw.md) | labs/112 (題目 5) |
| **runtime overhead** | 修正了所選 RuntimeClass 的 Pods 的調度程式所佔用的額外 CPU/記憶體。 | [22](22/tw.md) | |
| **RuntimeClass** | 叢集範圍的 Kubernetes 資源選擇 CRI 處理程序和可選的開銷/調度限制。 | [19](19/tw.md), [22](22/tw.md) | labs/110 (題目 1) |
| **RuntimeDefault** | 由所選容器運作時為 AppArmor 或 seccomp 提供的設定檔。 | [16](16/tw.md), [17](17/tw.md), [18](18/tw.md) | labs/106 (題目 3), labs/107 (題目 2) |
| **sandbox pool** | 專用節點集，預先準備好 runtime、label、taint 與所需容量。 | [22](22/tw.md) | labs/110 |
| **sandboxed runtime** | 具有更強隔離邊界的運作時，例如 gVisor 或 Kata Containers。 | [03](03/tw.md), [22](22/tw.md) | labs/110 (題目 1-3) |
| **SCMP_ACT_ERRNO** | seccomp 操作傳回系統呼叫錯誤而不執行它。 | [17](17/tw.md) | labs/106 (題目 4) |
| **SCMP_ACT_LOG** | seccomp 操作允許系統呼叫並請求核心日誌記錄。 | [17](17/tw.md) | |
| **seccomp** | Linux 機制過濾進程的系統呼叫。 | [03](03/tw.md), [17](17/tw.md), [18](18/tw.md) | labs/106 (題目 3-5, 7) |
| **SECCOMP audit record** | seccomp 相關事件的核心/稽核記錄。 | [17](17/tw.md) | |
| **Secret mount** | 暫時安裝一個建置命令的憑證，而不將其寫入最後一層。 | [24](24/tw.md) | |
| **security advisory** | 供應商關於受影響版本、利用條件、緩解措施和修復版本的主要通知。 | [13](13/tw.md) | |
| **SecurityContext** | Kubernetes 定義進程或 Pod 的身份和限制的欄位。 | [18](18/tw.md), [33](33/tw.md) | labs/106, labs/107 (題目 2) |
| **self-signed certificate** | 由自己的金鑰而不是受信任的 CA 簽署的憑證；適合測試但預設不可信。 | [08](08/tw.md) | labs/103 (題目 4) |
| **SELinux** | 基於標籤的 MAC，具有類型強制功能，補充了普通存取權限。 | [03](03/tw.md) | |
| **ServiceAccount (SA)** | Pods 的命名空間標識以及 Kubernetes API 中的進程。 | [11](11/tw.md), [23](23/tw.md) | labs/104 (題目 2-3) |
| **severity** | 結果的嚴重性類別：`LOW`、`MEDIUM`、`HIGH` 或 `CRITICAL`。 | [28](28/tw.md) | labs/111 (題目 1) |
| **SHA-256 checksum** | 256 位元檔案摘要，用於驗證與已發佈工件的逐位元組相等性。 | [09](09/tw.md) | labs/103 (題目 6) |
| **shim** | 將 containerd 與特定執行時間連接的 containerd 進程或二進位檔案。 | [22](22/tw.md) | labs/110 (題目 1) |
| **Sidecar** | 代理或其他輔助容器以及攔截或服務流量的應用程式。 | [23](23/tw.md) | labs/110 (題目 6) |
| **SLSA** | 軟體供應鏈安全實踐的成熟度模型。 | [25](25/tw.md) | |
| **Software supply chain** | 正在運行的工作負載的來源、相依性、建置系統和工件的路徑。 | [25](25/tw.md) | labs/111 |
| **SPDX** | 一種開放標準，描述 SBOM 中的包、許可證及其關係。 | [25](25/tw.md), [28](28/tw.md) | labs/111 (題目 6) |
| **SSRF** | 伺服器端請求偽造，一種導致伺服器請求攻擊者選擇的位址的漏洞。 | [05](05/tw.md) | labs/101 (題目 5) |
| **stage** | 審核事件建立階段：`RequestReceived`、`ResponseStarted`、`ResponseComplete` 或 `Panic`。 | [32](32/tw.md) | labs/112 (題目 4) |
| **static analysis** | 在不執行工作負載的情況下檢查 Dockerfile、清單和策略。 | [27](27/tw.md) | labs/111 (題目 2) |
| **static Pod** | 來自節點本地清單的 Pod，由 kubelet 管理，無需透過 Kubernetes API 進行調度。 | [07](07/tw.md), [09](09/tw.md), [12](12/tw.md), [32](32/tw.md), [33](33/tw.md) | labs/103, labs/104 (題目 5), labs/112 (題目 4) |
| **sudoers** | 使用者可以作為另一個使用者執行的命令的策略；使用 `visudo` 進行編輯。 | [15](15/tw.md) | |
| **SUID/SGID** | 使用擁有者的有效 UID 或群組的 GID 運行程式的特殊檔案位元。 | [15](15/tw.md) | |
| **support window** | 支援的版本分支接收安全補丁。 | [13](13/tw.md) | |
| **Syft** | 從影像、檔案系統或檔案產生 SBOM 的工具。 | [25](25/tw.md) | labs/111 (題目 7) |
| **syscall** | 進程透過其請求內核操作的系統呼叫。 | [03](03/tw.md), [17](17/tw.md), [29](29/tw.md) | labs/106 (題目 4-5) |
| **system:unauthenticated** | 匿名主體所屬群體；綁定需要與 `system:anonymous` 相同的審核。 | [12](12/tw.md) | |
| **systemd unit** | 服務、套接字、計時器或其他由 systemd 管理的實體的定義。 | [14](14/tw.md) | labs/105 (題目 1) |
| **TLS minimum version** | 伺服器將與客戶端協商的最低 TLS 版本。 | [09](09/tw.md) | labs/103 (題目 5) |
| **TLS Secret** | `kubernetes.io/tls` Secret 包含 `tls.crt` 和 `tls.key`。 | [08](08/tw.md) | labs/103 (題目 4) |
| **TLS termination** | 在入口控制器完成TLS握手並解密流量。 | [08](08/tw.md) | labs/103 (題目 4) |
| **toFQDNs** | 使用 DNS 名稱和觀察到的 DNS 回應的 Cilium 出口規則。 | [06](06/tw.md) | labs/102 (題目 4) |
| **TokenRequest API** | API 發行短期的 ServiceAccount 代幣。 | [11](11/tw.md) | labs/104 (題目 2) |
| **Transparent encryption** | 資料路徑加密，無需應用程式、Service或 URL 變更； Cilium 將其應用於節點。 | [23](23/tw.md) | labs/110 (題目 4) |
| **triage** | 按來源、風險、範圍和下一步行動快速對發現或事件進行分類。 | [33](33/tw.md) | |
| **Trivy** | 用於影像、SBOM、檔案系統、機密和配置/IaC 的掃描器。 | [28](28/tw.md), [33](33/tw.md) | labs/111 (題目 1, 5, 8) |
| **Unconfined** | 容器沒有seccomp過濾器；暫時的例外，而不是基準。 | [17](17/tw.md) | labs/106 (題目 5) |
| **Unix socket** | 本機檔案系統 IPC 端點；它的權限決定誰可以存取守護程式API。 | [14](14/tw.md) | labs/105 (題目 6) |
| **userns-remap** | Docker daemon 功能（`dockerd --userns-remap`），由 Docker 本身重新對應容器在主機上的 UID/GID；它與實驗 106 驗證的 Kubernetes Pod 使用者命名空間（`hostUsers: false`）是不同的機制。 | [14](14/tw.md) | |
| **Validating admission webhook** | 允許或拒絕物件的 Webhook。 | [20](20/tw.md) | |
| **ValidatingAdmissionPolicy** | API 伺服器內建 CEL 驗證，無需外部 Webhook；透過綁定應用程式。 | [20](20/tw.md) | labs/107 (題目 6) |
| **version skew** | Kubernetes元件之間允許的版本差異；kubelet 不得比 API 伺服器新。 | [13](13/tw.md) | |
| **webhook collector** | HTTPS 端點接收稽核事件以進行集中儲存和分析。 | [32](32/tw.md) | labs/112 (題目 8) |
| **WireGuard** | 具有對等密鑰對的 VPN 協定；公鑰標識允許的對等點。 | [23](23/tw.md) | labs/110 (題目 4-5) |
| **Workload identity** | 可加密驗證的工作負載身份，通常連結到網格中的 ServiceAccount/命名空間。 | [23](23/tw.md) | labs/110 (題目 6) |
| **Writable layer** | 運行時在唯讀影像層上新增的可變層。 | [31](31/tw.md) | |
| **Zero trust** | 拒絕基於網路、命名空間或位置的隱式信任。 | [02](02/tw.md) | |
