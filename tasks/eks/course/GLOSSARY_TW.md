[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [日本語版](GLOSSARY_JP.md)

# EKS 課程術語表

[課程目錄](README_TW.md)

本課程術語的統一字母順序參考。AWS 與 Kubernetes 中原本為英文的術語保留英文，說明採用繁體中文。「章節」欄列出討論該術語的章節連結。頁面內搜尋請使用 Ctrl+F。

| 術語 | 說明 | 章節 |
|--------|----------|-------|
| **ABAC / RBAC** | 透過 `aws:PrincipalTag` 的標籤式存取，對比以特定動作與資源角色和政策實作的存取。 | [0.2](00-2-iam/tw.md) |
| **Access entry** | 叢集存取設定中的記錄，將一個 IAM principal 對應到 `username` 與 `kubernetesGroups`；人員和服務使用 `STANDARD`，節點使用 `EC2_LINUX`、`EC2_WINDOWS`、`FARGATE_LINUX`、`HYBRID_LINUX`、`EC2`。 | [01](01/tw.md), [05](05/tw.md), [47](47/tw.md) |
| **access entry 類型 `EC2_LINUX`** | 在叢集中授權節點角色 ARN 的記錄。 | [45](45/tw.md) |
| **access point** | 具有自身權限與 POSIX 身分的 EFS 子目錄入口，是動態佈建與目錄隔離的基礎。 | [24](24/tw.md) |
| **Access policy** | 與 access entry 關聯的 AWS 受管 Kubernetes 層級權限政策；包含 verbs 與 resources，而非 IAM 權限，且不可編輯。 | [05](05/tw.md), [47](47/tw.md) |
| **Access scope** | access policy 的作用範圍：`cluster` 或含清單的 `namespace`。 | [05](05/tw.md) |
| **ACM (AWS Certificate Manager)** | 存放於負載平衡器的憑證；私鑰不可匯出，會自動續期。 | [27](27/tw.md), [29](29/tw.md) |
| **actions / conditions** | 自訂動作註解（redirect、fixed-response、weighted forward）及額外路由條件（標頭、方法、query、來源 IP）。 | [27](27/tw.md) |
| **Admission webhook** | apiserver 在將物件寫入 etcd 前呼叫的外部處理器；mutating 修改物件，validating 僅允許或拒絕。 | [22](22/tw.md) |
| **ADOT** | AWS Distro for OpenTelemetry：AWS 的 OTel 發行版（SDK、代理程式、Collector）。 | [36](36/tw.md) |
| **ALIAS** | 指向 AWS 資源（如 ELB）的 Route 53 記錄；可在禁止 CNAME 的網域 apex 使用，且不按獨立查詢計費。 | [29](29/tw.md) |
| **Allocatable** | 扣除 `kube-reserved`、`system-reserved` 與驅逐閾值後留給 Pod 的資源，scheduler 依此排程。 | [14](14/tw.md) |
| **`allowVolumeExpansion`** | StorageClass 旗標，允許透過擴大 PVC 增加磁碟區。 | [23](23/tw.md) |
| **Amazon EKS** | AWS 受管 Kubernetes：AWS 維護 control plane，節點與周邊由您負責。 | [01](01/tw.md) |
| **Amazon Managed Grafana (AMG)** | 受管 Grafana；將 AMP 作為 data source，使用者透過 IAM Identity Center 存取。 | [33](33/tw.md) |
| **Amazon Managed Service for Prometheus (AMP)** | 受管 Prometheus 相容後端；workspace、remote-write、PromQL 與 retention 由 AWS 提供。 | [33](33/tw.md) |
| **amazon-cloudwatch-observability** | 安裝 CloudWatch agent 並啟用 Container Insights with enhanced observability 的 EKS 受管附加元件。 | [33](33/tw.md) |
| **AMI (Amazon Machine Image)** | 執行個體磁碟範本：核心、檔案系統與軟體；節點使用已協調 `kubelet`、`containerd` 與 bootstrap 邏輯的 EKS 最佳化映像。 | [0.4](00-4-ec2/tw.md), [10](10/tw.md) |
| **API Priority and Fairness** | Kubernetes 在不同請求類型間分配並行請求配額的機制；耗盡時客戶端收到 `429`。 | [02](02/tw.md) |
| **app-of-apps** | 部署一組子 Application 的父 `Application`。 | [44](44/tw.md) |
| **Application** | Argo CD CRD：Git 來源加上目標叢集與 namespace 的組合。 | [44](44/tw.md) |
| **Application Load Balancer (ALB)** | 具 host/path 路由、TLS 終止、WAF 與驗證的 L7（HTTP/HTTPS）負載平衡器；EKS 中由 LBC 從 Ingress 建立。 | [27](27/tw.md) |
| **ApplicationSet** | Argo CD 控制器，依範本產生 `Application`；cluster generator 為每個已連線叢集建立一個，git generator 按 Git 目錄或檔案建立，matrix generator 將兩個 generator（cluster + git）相乘。 | [44](44/tw.md) |
| **ARN** | `arn:partition:service:region:account-id:resource`，資源位址。 | [0.1](00-1-aws/tw.md) |
| **`AssumeRoleWithWebIdentity`** | 將 web identity token 交換為 IAM 角色暫時性憑證的 STS 操作。 | [16](16/tw.md) |
| **auditID** | audit log 中請求的唯一識別碼；同一操作的所有 stage 相同。與 CloudTrail 沒有共用 ID，應依 principal、IP 與時間關聯。 | [21](21/tw.md) |
| **`authenticationMode`** | 叢集驗證模式：`CONFIG_MAP`、`API_AND_CONFIG_MAP`、`API`；僅能朝 `API` 遷移。 | [04](04/tw.md), [05](05/tw.md), [47](47/tw.md) |
| **`authenticationSource`** | 磁碟區憑證來源：`driver`（驅動程式共用角色）或 `pod`（Pod service account 角色）。 | [25](25/tw.md) |
| **Availability Zone (AZ)** | 區域中隔離的一組資料中心；配置副本的基本故障網域。 | [0.1](00-1-aws/tw.md), [40](40/tw.md) |
| **AWS Backup** | AWS 集中備份服務；依統一計畫與保存庫備份 EKS、EBS、EFS、S3 和其他資源。 | [41](41/tw.md) |
| **aws cli v2** | AWS 主要 CLI；設定於 `~/.aws/config`，透過 `--profile` 或 `AWS_PROFILE` 選擇存取。 | [0.5](00-5-tools/tw.md) |
| **AWS Control Tower** | AWS 現成 landing zone：controls（preventive、detective、proactive）、drift 偵測與 account factory。 | [0.1](00-1-aws/tw.md) |
| **`aws eks get-token`** | kubeconfig 的 `exec` 外掛，產生進入叢集的 presigned STS token。 | [47](47/tw.md) |
| **AWS Gateway API Controller** | 控制器 `aws-application-networking-k8s`，GatewayClass `amazon-vpc-lattice`，將 Gateway API 轉換為 VPC Lattice 物件。 | [28](28/tw.md) |
| **AWS Load Balancer Controller (Gateway API)** | 以 `controllerName` `gateway.k8s.aws/alb`（ALB、L7）及 `gateway.k8s.aws/nlb`（NLB、L4）實作。 | [28](28/tw.md) |
| **AWS Load Balancer Controller (LBC)** | 叢集內控制器，為 LoadBalancer 類型 Service 建立 NLB、為 Ingress 建立 ALB；以 Helm 安裝且需要 IAM 角色。 | [26](26/tw.md) |
| **AWS Organizations** | 多帳戶管理服務：OU 階層、共用政策（SCP）、合併帳單。 | [0.1](00-1-aws/tw.md), [32](32/tw.md) |
| **AWS PrivateLink** | 透過 interface endpoint 私密存取 AWS 服務及其他帳戶服務的機制。 | [31](31/tw.md) |
| **AWS RAM (Resource Access Manager)** | 與其他帳戶和組織分享資源（subnets、Transit Gateway、VPC Lattice service network、Route 53 Resolver rules）的服務。 | [0.1](00-1-aws/tw.md), [32](32/tw.md) |
| **`aws sts get-caller-identity`** | 「我是誰」命令：帳戶、ARN、userId。 | [0.5](00-5-tools/tw.md) |
| **AWS X-Ray** | 受管追蹤後端：儲存、service map、延遲分解與追蹤搜尋。 | [36](36/tw.md) |
| **`aws-auth` ConfigMap** | 在 `kube-system` 物件中以 `mapRoles` 和 `mapUsers` 欄位映射的 legacy 機制。 | [05](05/tw.md), [45](45/tw.md), [47](47/tw.md) |
| **aws-for-fluent-bit** | AWS 組建的 Fluent Bit 映像，內含輸出至 AWS 服務的外掛。 | [34](34/tw.md) |
| **`aws-vault`** | 在 keychain 儲存憑證，並在暫時性 session 中執行命令。 | [0.5](00-5-tools/tw.md) |
| **`AWS_VPC_K8S_CNI_EXTERNALSNAT`** | 移除 Pod egress 的節點 SNAT（`true`），使外部可見真實 Pod 位址；此時網際網路出口僅經由 NAT gateway。 | [07](07/tw.md) |
| **`AWSTraceHeader`** | SQS 訊息用於 X-Ray trace header 的系統屬性；在沒有標頭的非同步邊界傳遞 context 的方式。 | [36](36/tw.md) |
| **backend-protocol-version** | target group 的應用協定：`HTTP1`、`HTTP2` 或 `GRPC`；讓 ALB 以 gRPC/HTTP/2 而非 HTTP/1.1 代理至 Pod。 | [27](27/tw.md) |
| **backup plan** | 備份計畫：排程、retention、lifecycle（移至 cold storage）與資源關聯。 | [41](41/tw.md) |
| **backup vault** | 具有 KMS key 與存取政策的 recovery points 保存庫；可在此啟用 Vault Lock。 | [41](41/tw.md) |
| **BackupStorageLocation (BSL)** | Velero 備份儲存位置（S3 bucket）。 | [42](42/tw.md) |
| **bake period** | control plane 與節點升級之間的暫停期；節點保持 N-1，無須復原節點即可回滾。 | [39](39/tw.md) |
| **Basic / Enhanced scanning** | ECR CVE 掃描模式：basic 原生掃描 OS packages；enhanced 透過 Amazon Inspector 持續掃描 OS 與語言套件。 | [20](20/tw.md) |
| **behavior / stabilizationWindowSeconds** | 透過穩定化視窗與 policies 平滑擴縮速度與波動的 HPA 區段。 | [35](35/tw.md) |
| **bin packing** | 依 requests 將 Pod 裝箱至節點。 | [14](14/tw.md) |
| **blue/green 叢集** | 目標版本的新叢集與舊叢集並存，遷移工作負載後切換流量。 | [03](03/tw.md), [38](38/tw.md) |
| **bootstrap.sh** | 在 AL2 以 user data 設定 kubelet 的指令碼。 | [45](45/tw.md) |
| **`bootstrapClusterCreatorAdminPermissions`** | 建立時的存取設定欄位；`true`（預設）時叢集建立者取得叢集管理員權限。 | [04](04/tw.md), [05](05/tw.md) |
| **Bottlerocket** | 容器用最小化 OS：唯讀根目錄、整體映像更新、API 管理，以 control/admin containers 取代開放 SSH。 | [10](10/tw.md) |
| **Burstable (T 系列)** | 基礎 CPU 份額加 CPU credits；不適合 production 節點。 | [0.4](00-4-ec2/tw.md) |
| **Capacity** | 執行個體的完整 CPU、記憶體與 Pod 容量。 | [14](14/tw.md) |
| **Capacity Blocks** | 為訓練預約 GPU/Trainium 容量。 | [0.4](00-4-ec2/tw.md) |
| **capacity type** | 節點容量類型（`spot`/`on-demand`）；標籤 `karpenter.sh/capacity-type` 和 `eks.amazonaws.com/capacityType`。 | [13](13/tw.md) |
| **CapacityProvisioned** | Pod 註解，標示捨入後實際配置的 vCPU 與記憶體組合；此組合決定費用。 | [15](15/tw.md) |
| **cert-manager** | 在叢集內簽發 `Secret` 形式憑證的控制器；來源由 ClusterIssuer 或 Issuer 指定。 | [29](29/tw.md) |
| **CFS throttling** | 容器超過 CPU limit 時被限速。 | [14](14/tw.md) |
| **chargeback** | 將實際成本計入團隊預算。 | [43](43/tw.md) |
| **`CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy`** | 具 L7、FQDN 規則及叢集範圍的 Cilium CRD。 | [08](08/tw.md), [30](30/tw.md) |
| **CloudTrail** | AWS API 呼叫日誌；EKS 記錄作為 AWS 資源的叢集操作（management events），而非 Kubernetes 內部事件。 | [21](21/tw.md) |
| **CloudWatch Application Signals** | 建立於 OTel 之上的 APM（SLO、延遲、錯誤），透過 `amazon-cloudwatch-observability` 附加元件啟用。 | [36](36/tw.md) |
| **CloudWatch Logs** | AWS 日誌儲存體；log groups 和 log streams，以 Logs Insights 查詢，按 ingestion 與 storage 計費。 | [34](34/tw.md) |
| **CloudWatch Logs Insights** | 日誌查詢語言（`fields`、`filter`、`sort`、`stats`）；解析 audit log 的主要工具。 | [21](21/tw.md) |
| **Cluster Autoscaler (CA)** | 建置在 Auto Scaling group 之上的節點 autoscaler：依未排程 Pod 與未充分利用情況變更群組 `desiredSize`；執行個體類型固定於群組 launch template。 | [11](11/tw.md) |
| **cluster creator admin** | 建立叢集的 IAM principal 自動取得管理員存取權。 | [47](47/tw.md) |
| **Cluster endpoint** | 叢集 Kubernetes API 位址。Public endpoint 可自網際網路存取且僅受 CIDR 清單限制；private endpoint 可從 VPC 存取且受 cluster security group 限制。 | [01](01/tw.md), [02](02/tw.md) |
| **Cluster insights** | EKS 自動叢集檢查；`UPGRADE_READINESS` 是升級準備度，`ROLLBACK_READINESS` 是可回滾性，後者可用 7 天。 | [03](03/tw.md), [38](38/tw.md) |
| **Cluster security group** | 為叢集自動建立並附掛至這些網路介面及 managed node groups 節點的 security group。 | [02](02/tw.md), [45](45/tw.md) |
| **cluster version rollback** | 原地升級後於 7 天期間將 EKS control plane 回滾至前一 minor，保留 etcd、工作負載與磁碟區。 | [03](03/tw.md), [39](39/tw.md) |
| **ClusterIssuer / Issuer** | cert-manager 物件，描述整個叢集或 namespace 的憑證來源。 | [29](29/tw.md) |
| **ClusterMesh** | 透過 `clustermesh-apiserver` 連結多個 Cilium 叢集的 Pod Network；需要唯一 `cluster-id` 與不重疊 PodCIDR。 | [08](08/tw.md) |
| **CMK (customer managed key)** | 您的 KMS key：可控制 key policy 與在 CloudTrail 稽核解密，不同於預設 AWS owned key。 | [18](18/tw.md) |
| **CNI chaining** | VPC CNI 配發位址並設定介面，Cilium 在其上加入政策與觀測性；`aws-node` 保留。 | [08](08/tw.md), [30](30/tw.md) |
| **`cni-metrics-helper`** | 元件：從 `aws-node` Pod 擷取 `awscni_*` 並傳送彙總資料至 CloudWatch。 | [06](06/tw.md) |
| **composite recovery point** | 將叢集狀態與磁碟區備份組成單一單位的 EKS 複合復原點。 | [41](41/tw.md) |
| **Compute Savings Plans** | 以 1 至 3 年每小時消費承諾換取折扣，跨執行個體系列、區域與 Fargate/Lambda 彈性適用；承諾不跨小時、不適用 Spot，Cost Explorer 顯示 Savings Plans utilization（已用）與 coverage（已覆蓋）。 | [43](43/tw.md) |
| **Compute SP / EC2 Instance SP** | 彈性方案（EC2、Fargate、Lambda）/ 折扣較深但限同區域一個系列的方案。 | [0.4](00-4-ec2/tw.md) |
| **configurationValues** | 附加元件欄位，用於宣告式設定而不手動修改 manifests。 | [37](37/tw.md) |
| **connection draining** | 解除註冊 target 時排空現有連線；`deregistration_delay.timeout_seconds`（預設 300）。 | [40](40/tw.md) |
| **conntrack** | 節點核心的連線追蹤表；滿載時新連線會被丟棄。 | [46](46/tw.md) |
| **Consolidated billing** | 組織共用帳單；數量折扣與 Savings Plans 適用所有帳戶。 | [0.1](00-1-aws/tw.md) |
| **Consolidation** | 為成本進行自主整併；政策 `WhenEmpty`、`WhenEmptyOrUnderutilized`，方法 empty/single/multi-node，參數 `consolidateAfter`。 | [11](11/tw.md), [12](12/tw.md) |
| **Container Insights** | 使用 CloudWatch 監控 EKS：agent 收集節點與 Pod metrics，提供 CloudWatch dashboards 與 alarms。 | [33](33/tw.md) |
| **ContainerResource** | HPA metric 類型，計算 Pod 單一 container 而非所有 container 總和的使用率；適用 sidecar 稀釋應用程式指標時。 | [35](35/tw.md) |
| **context propagation** | 透過標頭（W3C Trace Context）在服務間傳遞 `trace id`，避免 trace 中斷。 | [36](36/tw.md) |
| **continuous profiling** | 持續收集程式碼 CPU 與記憶體 hot spots；AWS 中為 Amazon CodeGuru Profiler，eBPF profiler 有 Pyroscope 與 Parca。 | [36](36/tw.md) |
| **Control plane** | API server、scheduler、controller manager 與 etcd；EKS 中位於 AWS 帳戶、您的 VPC 之外，且 `kubectl get pods -n kube-system` 不可見。 | [01](01/tw.md) |
| **control plane logging** | 將 EKS 管理層日誌（`api`、`audit`、`authenticator`、`controllerManager`、`scheduler`）傳送至 CloudWatch Logs。 | [34](34/tw.md) |
| **core 附加元件** | `vpc-cni`、`kube-proxy`、`coredns`：每個叢集安裝的必要核心。 | [37](37/tw.md) |
| **cost allocation（成本分攤）** | 按消耗量或 requests 將 AWS 資源成本分配至 Kubernetes 物件（namespace、Deployment、label）。 | [43](43/tw.md) |
| **cost allocation tags** | 用於拆分帳單的 AWS tags；user-defined tags 必須在 Billing 主控台啟用。 | [43](43/tw.md) |
| **Cost and Usage Report** | S3 中的詳細 AWS billing；透過 Athena 讀取，可讓 OpenCost/Kubecost 以折扣後實際帳單核對 allocation。 | [43](43/tw.md) |
| **Cost Anomaly Detection** | AWS 服務，以 ML 偵測異常支出成長並以 email 或 SNS（經 AWS Chatbot 至 Slack/Teams）告警。 | [43](43/tw.md) |
| **crash-consistent / application-consistent** | 不停止寫入的快照 / 在應用程式層協調的快照；AWS Backup 對 EKS 僅提供前者。 | [41](41/tw.md) |
| **Cross-account ENI** | EKS 在您的 subnets 建立的 network interfaces，用於 control plane 至節點、kubelet API、webhooks 與 OIDC 通訊。 | [02](02/tw.md) |
| **cross-AZ 流量** | Availability Zones 間的資料傳輸；按傳輸量計費，通常雙向皆計。 | [31](31/tw.md) |
| **cross-zone load balancing** | 將流量分散到所有 AZ targets 的負載平衡模式；負載更均勻但 cross-AZ 更多。 | [31](31/tw.md) |
| **Custom networking** | secondary ENI 與 Pod 位址取自各 AZ 一個的 `ENIConfig` 所指定 subnet 和 security groups，依 `ENI_CONFIG_LABEL_DEF` label 選擇。 | [07](07/tw.md) |
| **custom.metrics.k8s.io** | HPA 的叢集物件自訂 metrics API（Pods、Object）。 | [35](35/tw.md) |
| **Data Firehose** | 將串流緩衝並路由至 S3、OpenSearch 等目的地的受管服務。 | [34](34/tw.md) |
| **Data plane** | 您的節點以及其上執行的一切。 | [01](01/tw.md) |
| **Delegated administrator** | 管理整個組織 GuardDuty/Security Hub 並可見所有成員 findings 的組織帳戶；按區域委派。 | [0.1](00-1-aws/tw.md), [21](21/tw.md) |
| **`deletionProtection`** | 禁止刪除叢集的旗標。 | [04](04/tw.md) |
| **deprecated / removed API** | `apiVersion` 先標示過時再移除；移除後含此版本的 manifests 無法套用。 | [38](38/tw.md) |
| **describe-addon-versions** | EKS API 操作：附加元件版本、與 Kubernetes minor 的相容性及 `defaultVersion`。 | [37](37/tw.md) |
| **`describe-target-health`** | 顯示 target group targets 狀態與原因的命令。 | [46](46/tw.md) |
| **Digest** | 映像內容的 `sha256` hash，不可變識別碼；以 digest 部署保證執行精確建置的 artifact，不同於可變 tag。 | [20](20/tw.md) |
| **Disruption budget** | 自主中斷速率限制：節點比例/數量、`schedule` 和 `duration` 視窗及與 `reasons` 的關聯。 | [12](12/tw.md) |
| **DNS-01** | 透過 TXT record 驗證網域所有權的 ACME 方法；Route 53 中由 cert-manager 建立。 | [29](29/tw.md) |
| **Drift** | 節點與期望狀態不符（新 AMI、變更 selectors 或 `requirements`）；在 consolidation 前執行。 | [12](12/tw.md) |
| **Dual-stack** | 具 IPv4 與 IPv6（`/56`、`/64`）的 VPC/subnets；IPv6 模式消除 Pod 位址不足。 | [0.3](00-3-vpc/tw.md) |
| **EBS / instance store** | 單一 AZ 的網路磁碟區 / 暫時性本機 NVMe。 | [0.4](00-4-ec2/tw.md) |
| **EBS CSI 驅動程式** | `aws-ebs-csi-driver`，provisioner 為 `ebs.csi.aws.com` 的受管附加元件；管理 EBS 磁碟區生命週期。 | [23](23/tw.md) |
| **EC2NodeClass** | 含 AWS 設定的 CRD（`karpenter.k8s.aws/v1`）：AMI、IAM role、subnets 和 SG、disks、IMDS。 | [12](12/tw.md) |
| **ECR** | AWS 受管 OCI image registry；每帳戶區域的 private registry 位址為 `<account-id>.dkr.ecr.<region>.amazonaws.com`，public registry 為 `public.ecr.aws`。 | [20](20/tw.md) |
| **EFS** | Amazon Elastic File System，具彈性容量與 ReadWriteMany 模式的受管區域 NFS。 | [24](24/tw.md) |
| **EFS CSI 驅動程式** | `aws-efs-csi-driver`，provisioner 為 `efs.csi.aws.com` 的受管附加元件；在預先建立的 file system 上運作。 | [24](24/tw.md) |
| **EKS audit log** | control plane 日誌類型（`audit`），JSON Kubernetes audit events：誰、哪個 verb、何種資源、從何處及結果；寫入 CloudWatch Logs。 | [21](21/tw.md) |
| **EKS authenticator** | control plane webhook，驗證 presigned STS token 並將 IAM identity 映射至 Kubernetes subject。 | [47](47/tw.md) |
| **EKS Auto Mode** | AWS 管理 appliance nodes（Bottlerocket、唯讀 root、無 SSH/SSM、21 天生命期）、Karpenter 擴縮與內建 networking、DNS、EBS CSI、ELB 的模式。 | [01](01/tw.md), [09](09/tw.md) |
| **EKS Cluster State** | Kubernetes 物件 manifests（Secret、ConfigMap、StatefulSet、PVC、RBAC、CRD 等）加上叢集設定。 | [41](41/tw.md) |
| **EKS Pod Identity** | 由節點 agent 與 EKS API 向 Pod 發放 IAM role 的機制，無需叢集 OIDC provider，也無需綁定特定叢集的 trust policy。 | [17](17/tw.md), [47](47/tw.md) |
| **EKS Pod Identity Agent** | 節點上以 `DaemonSet` 運作的 `eks-pod-identity-agent` 附加元件，透過 local endpoint 發放暫時性憑證。 | [17](17/tw.md) |
| **EKS 最佳化 AMI** | AWS 提供、含適當版本節點元件的映像；系列為 AL2023、Bottlerocket、Windows 和即將淘汰的 AL2。 | [10](10/tw.md) |
| **eksctl** | EKS 官方 CLI，經由 CloudFormation 運作，採 imperative 方式。 | [0.5](00-5-tools/tw.md) |
| **enableNetworkPolicy** | 啟用標準 NetworkPolicy enforcement 的 VPC CNI managed addon 參數。 | [30](30/tw.md) |
| **Encryption at rest** | ECR layer 加密：預設 SSE-S3（AES-256），可選用 `aws/ecr` 或自有 customer managed key 的 SSE-KMS；建立時設定且不可變。 | [20](20/tw.md) |
| **endpoint service** | 將自有服務（位於 NLB 後）發佈為 PrivateLink 目標，供其他 VPC/帳戶使用。 | [31](31/tw.md) |
| **`endpointPublicAccess` / `endpointPrivateAccess`** | 存取模式布林旗標；預設 `true` 與 `false`。 | [02](02/tw.md) |
| **enforcer** | 將 NetworkPolicy 變為實際流量過濾器的 CNI 元件；EKS 預設沒有，須先啟用。 | [30](30/tw.md) |
| **Enhanced subnet discovery** | 帶有 `kubernetes.io/role/cni=1` tag、無 `ENIConfig` 的 subnets。 | [07](07/tw.md) |
| **ENI** | elastic network interface；每個 instance 的 ENI 數及每個 ENI 的 IPv4 位址數取決於 instance type。 | [0.3](00-3-vpc/tw.md), [06](06/tw.md) |
| **Envelope encryption** | 雙金鑰加密：DEK 加密資料，KEK（KMS key）加密 DEK；EKS 以 Kubernetes KMS provider v2 加密 etcd secrets。 | [18](18/tw.md) |
| **ephemeral ports** | 反向流量使用的高範圍 `1024-65535`；NACL 必須手動允許。 | [46](46/tw.md) |
| **eviction threshold** | 記憶體低於此緩衝值時 kubelet 驅逐 Pod。 | [14](14/tw.md) |
| **exec kubeconfig 外掛** | 呼叫 `aws eks get-token` 的 `exec` 區段；檔案不含長期 token，`client-go` 將取得的憑證快取至 `status.expirationTimestamp`。 | [0.5](00-5-tools/tw.md) |
| **Expander** | Pod 適合多個 node group 時 Cluster Autoscaler 的選擇策略：`least-waste`（預設）、`priority`、`most-pods`、`random`。 | [11](11/tw.md) |
| **Extended support** | standard 後的階段（約 12 個月）：版本仍受支援但每小時叢集費用提高；預設啟用。 | [03](03/tw.md), [38](38/tw.md) |
| **External Secrets Operator (ESO)** | 從 AWS 讀取 secret 並建立原生 `Secret` 的控制器；使用 `SecretStore`/`ClusterSecretStore` 及 `ExternalSecret` 物件。 | [18](18/tw.md) |
| **external-dns** | 將 DNS records 與 Kubernetes 物件（Ingress、Service）同步至 provider 的控制器；AWS 使用 Route 53。 | [29](29/tw.md) |
| **external.metrics.k8s.io** | HPA（External 類型）用的外部 metrics API（queues、topics）。 | [35](35/tw.md) |
| **externalTrafficPolicy** | Service 政策：`Cluster`（轉送至任一節點、SNAT）或 `Local`（僅本機 Pods、保留 client IP）。 | [26](26/tw.md) |
| **`failed to assign an IP address to container`** | VPC CNI 未能為 Pod 配發 IP：節點或 subnet 位址已耗盡。 | [46](46/tw.md) |
| **failurePolicy** | webhook 無法使用時的反應：`Fail` 停止 admission，`Ignore` 讓物件略過檢查。 | [22](22/tw.md) |
| **Fargate** | 在專用 micro-VM 執行 Pod、無節點；無 DaemonSet、privileges、`HostNetwork`、GPU 與節點存取。按 Pod vCPU 和記憶體收費。 | [09](09/tw.md) |
| **fargate-scheduler** | 與 kube-scheduler 一起運作的 EKS scheduler，將符合 profile 的 Pods 導向 Fargate。 | [15](15/tw.md) |
| **Fargate profile** | 含 selectors（namespace 加可選 labels）、pod execution role 和 private subnets 的叢集層級物件；決定哪些 Pods 進入 Fargate。不可修改，只能重建。 | [15](15/tw.md) |
| **Finding** | GuardDuty finding；送至 Security Hub 與 EventBridge 以供告警和回應。 | [21](21/tw.md) |
| **Fluent Bit** | 以 C 編寫的輕量 log forwarder，在每節點以 DaemonSet 執行；讀取日誌檔、充實資料並送至目的地。 | [34](34/tw.md) |
| **Forbidden (403)** | 授權失敗：RBAC 未允許該動作。 | [47](47/tw.md) |
| **game day** | 實際演練 DR 與 incident scenarios 的訓練。 | [48](48/tw.md) |
| **Gatekeeper** | 建立於 OPA 的 policy engine；Rego rules，`ConstraintTemplate`（範本加 schema）和 `Constraint`（實例）模型。 | [22](22/tw.md) |
| **Gateway** | 含 listeners（protocol、port、TLS）的入口點；由 platform team 擁有。在 VPC Lattice 中映射至 Service Network。 | [28](28/tw.md) |
| **Gateway API** | Kubernetes 流量管理標準、Ingress 的後繼者：一組分離角色的型別化資源。 | [28](28/tw.md) |
| **gateway endpoint** | 經 route table 記錄存取 S3 與 DynamoDB 的 VPC endpoint 類型；免費。 | [25](25/tw.md), [31](31/tw.md) |
| **GatewayClass** | 具 `controllerName` 欄位的實作範本；決定哪個 controller 處理 Gateway（相當於 IngressClass）。 | [28](28/tw.md) |
| **GitOps** | 在 Git 描述期望狀態、agent 持續使叢集一致的模型（原則由 CNCF 專案 OpenGitOps 定義）。 | [44](44/tw.md) |
| **GitOps Toolkit** | Flux controllers 集合（source、kustomize、helm、image 等）。 | [44](44/tw.md) |
| **Golden image** | 透過 image builder 在最佳化 AMI 上建立的可重現 custom image。 | [10](10/tw.md) |
| **graceful node shutdown** | OS 停止時 kubelet 以 grace period 終止 Pods 的功能。 | [40](40/tw.md) |
| **Grafana Loki** | 僅索引 stream labels 的日誌儲存體；日誌壓縮為 object storage chunks，以 LogQL 查詢。labels 應低 cardinality，高 cardinality 使用 structured metadata；原生 agent 是 Grafana Alloy（Promtail 已併入）。 | [34](34/tw.md) |
| **`granted` (`assume`)** | 快速切換 SSO profiles 並登入主控台。 | [0.5](00-5-tools/tw.md) |
| **Graviton** | AWS arm64 processors（後綴 `g`），需要 multi-arch images。 | [0.4](00-4-ec2/tw.md) |
| **GuardDuty EKS Protection** | 透過 GuardDuty 自有獨立串流分析 EKS audit logs 中的威脅，無須強制啟用 control plane logging。 | [21](21/tw.md) |
| **GuardDuty Runtime Monitoring** | 透過 `aws-guardduty-agent`（eBPF）觀察節點行為：processes、network、files；不支援 Fargate 與 Hybrid Nodes。 | [21](21/tw.md) |
| **Hard multi-tenancy** | tenants 位於不同 clusters/accounts；界線嚴格但複雜度高。 | [22](22/tw.md) |
| **HashiCorp Vault** | 非 AWS 的外部 secrets store，與 Secrets Manager 定位相同：Pod 以 Kubernetes、JWT/OIDC 或 AWS IAM auth 驗證；透過 Vault Agent Injector、Vault Secrets Operator、ESO 或含 Vault provider 的 CSI Driver 發送。 | [18](18/tw.md) |
| **head-based 與 tail-based sampling** | 在入口、得知請求結果前決定記錄，對比在收集完整 trace 後於 gateway 依錯誤與延遲政策決定。Tail-based 要求一個 trace 所有 spans 到同一 collector instance。 | [36](36/tw.md) |
| **helmfile** | 在單一檔案中宣告一組含 versions 和 values 的 helm releases。 | [0.5](00-5-tools/tw.md) |
| **hop limit (`httpPutResponseHopLimit`)** | IMDS 回應的網路 hops 數；為 1 時 Pod 無法到達 IMDS，節點仍可運作。 | [19](19/tw.md) |
| **hosted zone** | Route 53 的網域 DNS records 容器；可為 public（internet）或 private（附掛 VPC）。 | [29](29/tw.md) |
| **HPA (HorizontalPodAutoscaler)** | 依 metric 變更 Deployment replicas 數的 controller。 | [35](35/tw.md) |
| **HTTPRoute** | 依 host、path、headers 路由至 backend 的規則；以 `parentRefs` 參照 Gateway。在 VPC Lattice 中映射為 VPC Lattice Service。 | [28](28/tw.md) |
| **hub-and-spoke** | 以中央 Transit Gateway（hub）和連接的團隊 VPC（spokes）組成的拓撲。 | [32](32/tw.md) |
| **Hubble** | Cilium observability subsystem：流量地圖和 per-flow verdict，VPC CNI network policy 沒有此能力。 | [08](08/tw.md), [30](30/tw.md) |
| **IAM Access Analyzer** | 尋找 resource-based policies 與 trust policy 中外部 trusted entities（external access）。 | [0.2](00-2-iam/tw.md) |
| **IAM auth policy** | 用於服務間流量授權的 IAM 格式 policy；controller 中的資源是 `IAMAuthPolicy`。 | [28](28/tw.md) |
| **IAM database authentication** | 以暫時性 token（`aws rds generate-db-auth-token`，預設 15 分鐘）登入 RDS/Aurora 取代密碼；無需 rotation。 | [18](18/tw.md) |
| **IAM Identity Center** | 以 permission sets 提供單一登入與存取授予。 | [0.1](00-1-aws/tw.md) |
| **IAM OIDC identity provider** | 註冊叢集 issuer URL 的 IAM object；role trust policies 參照它。每叢集只建立一次。 | [16](16/tw.md) |
| **IAM role** | 無長期 keys、可被暫時 assume 的 identity。 | [0.2](00-2-iam/tw.md) |
| **IAM user / group** | 長期 identity 與該等 identities 的集合；production 應避免。 | [0.2](00-2-iam/tw.md) |
| **idle 容量** | 已付費節點容量與實際消耗間的差額；過高 requests 與不佳 bin-packing 的指標。 | [43](43/tw.md) |
| **image automation** | 將新 image tags 提交回 Git 的 Flux controllers。 | [44](44/tw.md) |
| **IMDS** | 位於 `169.254.169.254` 的 Instance Metadata Service；節點 metadata 與 role credentials 來源。IMDSv1 無 token，IMDSv2 為 session-based（`PUT`+token）。 | [0.2](00-2-iam/tw.md), [0.4](00-4-ec2/tw.md), [19](19/tw.md) |
| **Immutable 參數** | 建立後無法變更的叢集參數：`ipFamily`、custom `serviceIpv4Cidr`、VPC、名稱與叢集 IAM role。 | [04](04/tw.md) |
| **In-place upgrade** | 將同一叢集升至下一個 minor：control plane，然後 addons，然後 nodes。 | [03](03/tw.md), [38](38/tw.md) |
| **in-tree cloud provider** | Kubernetes 元件內建的 AWS 程式碼，預設為 LoadBalancer 類型 Service 建立 Classic Load Balancer。 | [26](26/tw.md) |
| **in-tree provisioner** | 內建 `kubernetes.io/aws-ebs`，已 deprecated，無 `gp3` 與 snapshots；EKS 預設 `gp2` 仍使用它。 | [23](23/tw.md) |
| **IngressClass alb** | 控制器為 `ingress.k8s.aws/alb` 的 class；具 `ingressClassName: alb` 的 Ingress 由 AWS Load Balancer Controller 處理。 | [27](27/tw.md) |
| **IngressGroup** | 以 `group.name` 將多個 Ingress 合併至一個共用 ALB；`group.order` 設定規則優先順序。 | [27](27/tw.md) |
| **INPUT / FILTER / OUTPUT** | Fluent Bit pipeline 的三種區段：讀取、處理、傳送。 | [34](34/tw.md) |
| **`InsufficientCidrBlocks`** | EC2 API 錯誤：形式上有可用位址但缺少連續 blocks。 | [07](07/tw.md) |
| **Interface endpoint** | 基於 PrivateLink 的 VPC endpoint 類型：subnet 中的 ENI，按小時加資料量收費。 | [31](31/tw.md) |
| **Internet Gateway** | 為 public addresses 提供網際網路出口的免費 gateway。 | [0.3](00-3-vpc/tw.md) |
| **involuntary disruption** | 非受控中斷：node/AZ failure、OOM、spot interruption；應靠分散配置而非 PDB 防護。 | [40](40/tw.md) |
| **ipamd** | `aws-node` 內 daemon，管理節點位址池：附加 secondary addresses 並透過 EC2 API 建立 ENI。 | [06](06/tw.md) |
| **`ipFamily`** | 叢集 address family，只能在建立時設定。 | [07](07/tw.md) |
| **IRSA** | IAM Roles for Service Accounts：依 OIDC federation，經繫結的 `ServiceAccount` 為 Pod 配發 IAM role。 | [0.2](00-2-iam/tw.md), [16](16/tw.md), [47](47/tw.md) |
| **Karpenter** | 節點 autoscaler，直接為特定未排程 Pods 建立 EC2 instances，並從允許範圍自行選擇 type。 | [11](11/tw.md) |
| **KEDA** | event-driven autoscaling 擴充：向 HPA 提供 metrics 並管理它。 | [35](35/tw.md) |
| **`kms:CreateGrant`** | 無此權限時 driver 可用自己的 CMK 建立 volume 卻無法 mount：EBS encryption 經由 grants，key policy 也需允許。 | [23](23/tw.md) |
| **krew** | plugin manager：index、`search`、`install`、`upgrade`；支援自訂 indexes。 | [0.5](00-5-tools/tw.md) |
| **kube-prometheus-stack** | 含 Prometheus Operator、Prometheus、Grafana、Alertmanager、node-exporter 和 kube-state-metrics 的 Helm chart。 | [33](33/tw.md) |
| **`kube-reserved` / `system-reserved`** | kubelet 分別為 Kubernetes 與 OS 保留的 resources。 | [14](14/tw.md) |
| **kube-state-metrics** | 將 Kubernetes objects 狀態（Pending、replicas、restarts）輸出為 metrics 的元件。 | [33](33/tw.md) |
| **Kubecost** | 基於 OpenCost 的產品，提供 UI、reports、recommendations；EKS 有 EKS-optimized bundle（add-on 或 Helm）。 | [43](43/tw.md) |
| **`kubectl plugin list`** | kubectl 在 `PATH` 中可見的項目。 | [0.5](00-5-tools/tw.md) |
| **`kubeProxyReplacement`** | Cilium 模式，以 eBPF 取代 kube-proxy 進行 Service/NodePort balancing；`true` 啟用替換。需要較新核心及對 balancing 的控制。 | [08](08/tw.md) |
| **Kustomization / HelmRelease** | Flux CRD：從來源將何物套用至何處。 | [44](44/tw.md) |
| **Kyverno** | policy engine，policy 為 YAML resource（`ClusterPolicy`/`Policy`），含 validate/mutate/generate/verifyImages 規則；反應為 `Enforce`/`Audit`。 | [22](22/tw.md) |
| **Landing zone** | 預先設定的多帳戶架構（management、shared services、environments、teams）；可透過 AWS Control Tower 部署。 | [0.1](00-1-aws/tw.md), [32](32/tw.md) |
| **Launch template** | 版本化 instance template（AMI、type、disk、SG、user data、IMDS）；managed node group 必定透過它部署。 | [10](10/tw.md) |
| **Launch template / Auto Scaling group** | 版本化 launch template / 依 AZ subnets 具 `min`、`desired`、`max` 的 instance group。 | [0.4](00-4-ec2/tw.md) |
| **Lifecycle policy** | 依年齡或數量自動刪除 images 的規則。 | [20](20/tw.md) |
| **limits** | container 消耗的上限。 | [14](14/tw.md) |
| **log group / log stream** | CloudWatch Logs 中的 group（通常每應用程式）與其中 stream（通常每 Pod）。 | [34](34/tw.md) |
| **Managed / inline policy** | 可重用、可版本化的 policy / 內嵌至 role 的 policy。 | [0.2](00-2-iam/tw.md) |
| **Managed addon (EKS managed addon)** | AWS 維護的叢集元件（VPC CNI、CoreDNS、kube-proxy、CSI），版本由 EKS API 管理。 | [0.5](00-5-tools/tw.md), [01](01/tw.md), [37](37/tw.md) |
| **managed collector (scraper)** | 無 agent 的 AMP 受管 collector，scrape EKS metrics 並經 remote-write 寫入 workspace。 | [33](33/tw.md) |
| **managed fields / server-side apply** | addon 宣告及套用自身 fields 的機制；conflict resolution 以此為基礎。 | [37](37/tw.md) |
| **Managed node group** | EKS 管理的 EC2 group：AWS 管理 ASG 與 launch template，依指令 drain 更新，但 OS 與 node 內容由您負責。 | [01](01/tw.md), [09](09/tw.md) |
| **Management account** | root billing account，不應承載工作負載。 | [0.1](00-1-aws/tw.md) |
| **`matchLabelKeys`** | 加入配置限制 `labelSelector` 的 Pod label keys；搭配 `pod-template-hash`，skew 在同一 Deployment revision 內計算。 | [40](40/tw.md) |
| **max-pods** | 每 node Pod 上限：`ENI * (IP per ENI - 1) + 2`，managed node groups 上限為 110 或 250。 | [0.4](00-4-ec2/tw.md), [06](06/tw.md), [46](46/tw.md) |
| **maxSkew** | 最滿與最空 domain 間 Pod 數量的允許偏差。 | [40](40/tw.md) |
| **`memory_limiter`** | 限制記憶體消耗的 Collector processor：達閾值時拒收資料而非進入 `OOMKilled`；應置於第一個。 | [36](36/tw.md) |
| **metric_relabel_configs** | scrape config 區段（ServiceMonitor 中為 `metricRelabelings`），於寫入與 remote-write 前丟棄高 cardinality metrics（按 `__name__` 的 `drop`）與 labels（`labeldrop`）；用於控制量與成本。 | [33](33/tw.md) |
| **Metrics API (`metrics.k8s.io`)** | Kubernetes 當前 resource metrics API，為 `kubectl top` 與依 resource metrics 的 HPA 提供來源。 | [33](33/tw.md), [35](35/tw.md) |
| **metrics-server** | 從 kubelet 收集 CPU/記憶體、透過 Metrics API 提供給 `kubectl top` 和 HPA 的元件；無歷史與儲存。 | [33](33/tw.md) |
| **mount target** | 特定 AZ subnet 中的 EFS network interface；該 AZ nodes 的入口，每 AZ 一個。 | [24](24/tw.md) |
| **Mountpoint for Amazon S3** | 經由 file interface 提供 bucket objects 的 client；是 CSI driver 的基礎。 | [25](25/tw.md) |
| **Mountpoint S3 CSI 驅動程式** | `aws-mountpoint-s3-csi-driver`，provisioner 為 `s3.csi.aws.com` 的 managed addon；僅支援 static provisioning。 | [25](25/tw.md) |
| **must have** | 缺少即會使 production 上線危險且應被阻止的項目。 | [48](48/tw.md) |
| **NACL** | subnet 層級 stateless filter；inbound 與 outbound rules 彼此獨立。 | [46](46/tw.md) |
| **namespace restore** | 在既有叢集中對最多 5 個 namespaces 進行細部 restore，不含 cluster-scoped resources（相關 PV 除外）。 | [42](42/tw.md) |
| **NAT Gateway** | 為 private subnets 提供 internet egress 位址轉譯的受管 AWS 服務；按小時與處理 GB 計費。 | [0.3](00-3-vpc/tw.md), [31](31/tw.md) |
| **`ndots:5`** | Pod resolv.conf 設定，使名稱依序嘗試 search domains。 | [46](46/tw.md) |
| **nested (child) recovery point** | composite 內的內嵌 recovery point：叢集狀態或個別 volume。 | [41](41/tw.md) |
| **Network ACL** | subnet 上的 stateless filter，按 rule numbers allow/deny。 | [0.3](00-3-vpc/tw.md) |
| **`NETWORK_POLICY_ENFORCING_MODE`** | Pod 啟動時套用 policies 的模式：`standard`（default allow，有無 policy 視窗）或 `strict`（default deny）。 | [08](08/tw.md), [30](30/tw.md) |
| **NetworkPolicy** | 宣告 Pods 允許 ingress 與 egress 的標準 Kubernetes object；無 enforcer 自身不會封鎖任何內容。 | [30](30/tw.md) |
| **nice to have** | 提升成熟度、可在 production 中補完的項目。 | [48](48/tw.md) |
| **NLB (Network Load Balancer)** | L4（TCP/UDP）負載平衡器，高效能、static IP；由 LBC 從 LoadBalancer 類型 Service 建立。 | [26](26/tw.md) |
| **node instance role** | EC2 node assume 的 IAM role；kubelet 以此呼叫 AWS API。 | [45](45/tw.md) |
| **Node Termination Handler (NTH)** | AWS 元件，處理無 Karpenter 的 managed 與 self-managed nodes interruptions；有 IMDS 與 Queue Processor modes。 | [13](13/tw.md) |
| **nodeadm** | AL2023 和 Bottlerocket node initializer；輸入為 YAML manifest `NodeConfig`（`apiVersion: node.eks.aws/v1alpha1`），取代 `bootstrap.sh`。 | [10](10/tw.md), [45](45/tw.md) |
| **NodeClaim** | Karpenter 對特定 node 的 claim；連結 `NodePool` 與實際 `Node`。 | [12](12/tw.md) |
| **NodeCreationFailure** | managed node group health issue：nodes 啟動後 15 分鐘內未加入叢集。 | [45](45/tw.md) |
| **NodeLocal DNSCache** | node 本機 caching DNS，降低 CoreDNS 負載與 per-ENI throttling。 | [46](46/tw.md) |
| **NodePool** | CRD（`karpenter.sh/v1`），設定 node 邊界：`requirements`、`limits`、`weight`、labels/taints、disruption policy。 | [12](12/tw.md) |
| **NodePool 與 NodeClass** | 描述要建立何種 nodes 及如何建立的 objects；Auto Mode default 不可變，仍可新增自訂物件。 | [09](09/tw.md) |
| **non-destructive restore** | 現有 objects 不覆寫而略過的模式（略過項目可經 SNS 看見）。 | [42](42/tw.md) |
| **kubelet 存活時的 NotReady** | 通常為 CNI 未就緒，Pods 無法取得 IP。 | [45](45/tw.md) |
| **OIDC issuer URL** | 叢集 public OIDC endpoint（`oidc.eks.<region>.amazonaws.com/id/`），含 projected tokens 的 public signing keys。 | [16](16/tw.md) |
| **On-demand / Spot** | 隨用隨付 / 折扣容量，會在兩分鐘前中斷。 | [0.4](00-4-ec2/tw.md) |
| **OOMKilled** | 超過 memory limit 時 container 被 kernel 終止。 | [14](14/tw.md) |
| **OpenCost** | 開放、vendor-neutral 的成本 allocation standard 與 engine，CNCF project；從 Prometheus 取得用量與 AWS resource prices。 | [43](43/tw.md) |
| **OpenSearch Service** | 用於 full-text search 與 dashboards 的受管 OpenSearch；按 cluster（nodes）計費。 | [34](34/tw.md) |
| **OpenTelemetry (OTel)** | CNCF standard：統一 API、SDK 與 protocol；分離 instrumentation 和 backend。 | [36](36/tw.md) |
| **OpenTelemetry Collector** | 收集器：receivers 接收、processors 處理、exporters 將 telemetry 匯出至 backends。 | [36](36/tw.md) |
| **OpenTelemetry Operator** | 以在 Pod 注入 agent 實現 auto-instrumentation 的 operator。 | [36](36/tw.md) |
| **OpenTofu** | terraform 的開放 fork，與課程 modules 相容；以 `terraform_binary = "tofu"` 屬性選擇。 | [0.5](00-5-tools/tw.md) |
| **OTLP** | 應用程式至 collector、以及 collectors 之間的 telemetry 傳輸 protocol。 | [36](36/tw.md) |
| **OU** | 套用 policies 的 account group。 | [0.1](00-1-aws/tw.md) |
| **ownership** | 對 domain 或 checklist item 的明確責任歸屬。 | [48](48/tw.md) |
| **Permissions boundary** | role 或 user 的權限上限，本身不授權。 | [0.2](00-2-iam/tw.md) |
| **Placement group** | instance placement 控制：`cluster`（相鄰、最低延遲、單一 AZ）、`partition`（按 partitions 分散 racks、每 AZ 最多 7）、`spread`（每個在不同硬體、每 AZ 最多 7 個運作）。 | [0.4](00-4-ec2/tw.md) |
| **`placementGroupSelector`** | 自訂 `NodeClass` 欄位，按名稱或 id 選擇 placement group。group 須自行預建；Pod 以 `eks.amazonaws.com/placement-group-id` label 的 `nodeSelector` 指定 group。 | [09](09/tw.md), [12](12/tw.md) |
| **Platform version** | Kubernetes minor 版本內 EKS control plane 的 patch 層級與功能集合，格式 `eks.<n>`，由 AWS 自動更新。 | [01](01/tw.md), [02](02/tw.md) |
| **pluto / kube-no-trouble (kubent)** | 過時 API 掃描工具：pluto 針對 Git 與 Helm，kubent 針對運行中叢集。 | [38](38/tw.md) |
| **Pod execution role** | Fargate substrate 上 `kubelet` 用以註冊叢集及從 ECR 拉映像的 IAM role；建立 profile 時設定。內建 log router 也以它寫入接收端，故日誌寫入權限須授予它。 | [15](15/tw.md) |
| **Pod Identity association** | EKS API 中連結 `叢集 + namespace + ServiceAccount` 與 IAM role 的記錄；用 `aws eks create-pod-identity-association` 建立。 | [17](17/tw.md), [37](37/tw.md) |
| **pod readiness gate** | Pod 的額外 readiness condition；AWS Load Balancer Controller 會保持 `target-health.elbv2.k8s.aws` 為 false，直到 target 成為 `healthy`。 | [40](40/tw.md) |
| **Pod Security Admission (PSA)** | 內建 admission controller，以 labels 在 namespace 套用 Pod Security Standards；取代 Pod Security Policies。 | [19](19/tw.md) |
| **Pod Security Standards** | privileged、baseline、restricted（嚴格、production 用）profiles。 | [19](19/tw.md) |
| **`POD_SECURITY_GROUP_ENFORCING_MODE`** | 無 source NAT 的 `strict`，對比 `standard`：VPC 外流量以 primary ENI、按 node SG rules 傳送。 | [46](46/tw.md) |
| **PodDisruptionBudget (PDB)** | 限制 voluntary disruptions 時可同時 eviction Pods 數的物件（`minAvailable`/`maxUnavailable`）。 | [40](40/tw.md) |
| **`pods.eks.amazonaws.com`** | Pod Identity role trust policy 的 service principal；所有 clusters/accounts 共用。EKS Auth API 透過 `AssumeRoleForPodIdentity` 發放 role credentials。 | [17](17/tw.md) |
| **Policy** | 包含 `Version`、`Statement`、`Effect`、`Action`、`Resource`、`Condition` 的 JSON；分為 identity-based（在 principal 上）和 resource-based（在 resource 上）。 | [0.2](00-2-iam/tw.md) |
| **Policy engine** | 含自訂規則（Kyverno、Gatekeeper）的 admission webhook；在寫入 etcd 前依規則檢查並可修改 objects。 | [22](22/tw.md) |
| **`pollingInterval` 與 `cooldownPeriod`** | KEDA source polling 週期（預設 30 秒）及 scale-to-zero 前等待時間（預設 300 秒）；後者僅作用於 scale-to-zero。 | [35](35/tw.md) |
| **Prefix delegation** | ENI slot 由 `/28` prefix（16 位址）佔用的模式；以 `ENABLE_PREFIX_DELEGATION` 啟用，需要 Nitro。 | [07](07/tw.md), [46](46/tw.md) |
| **preserve_client_ip** | NLB target group attribute，控制 `ip` 模式保留原始 client IP。 | [26](26/tw.md) |
| **preStop** | 在 SIGTERM 前執行的 hook；用於停止前暫停。 | [40](40/tw.md) |
| **Principal** | 執行請求者：user、role、AWS service。 | [0.2](00-2-iam/tw.md) |
| **private / public endpoint** | 叢集 API server 存取模式。 | [45](45/tw.md) |
| **Private hosted zone** | EKS 建立並關聯至您的 VPC 的 Route 53 zone，使 endpoint name 解析為 private address。 | [02](02/tw.md) |
| **Projected service account token** | 含 SA identity、audience `sts.amazonaws.com` 和生命期的 OIDC 相容 JWT；mount 至 Pod 並在 STS 交換 credentials。 | [16](16/tw.md) |
| **prometheus-adapter** | 將 Prometheus metrics 發佈至 custom/external API 的 adapter。 | [35](35/tw.md) |
| **provisioningMode: efs-ap** | StorageClass 模式，driver 為每個 PVC 建立 access point。 | [24](24/tw.md) |
| **`publicAccessCidrs`** | 允許 public endpoint 的 CIDR 清單；預設 `0.0.0.0/0`。 | [02](02/tw.md) |
| **Pull through cache** | ECR 規則，按需將 external registry（Docker Hub、Quay、`registry.k8s.io` 等）images 快取至您的 private ECR。 | [20](20/tw.md) |
| **pull 模型** | 叢集內 agent 自行從 Git 拉取；push 是外部 pipeline。 | [44](44/tw.md) |
| **QoS 類別** | `Guaranteed`、`Burstable` 或 `BestEffort`；決定記憶體不足時的 eviction 順序。 | [14](14/tw.md) |
| **ReadWriteMany (RWX)** | access mode：volume 可同時 mount 給多個 nodes 上的多個 Pods 寫入。 | [24](24/tw.md) |
| **Rebalance recommendation** | 早於兩分鐘通知、代表回收風險提高的預警；可預先遷出負載。 | [13](13/tw.md) |
| **recovery point** | 成功 backup job 的結果，即復原點。 | [41](41/tw.md) |
| **ReferenceGrant** | 目標 resource namespace 中的 Gateway API resource；允許列出的 namespaces 對其進行跨 namespace 參照（`backendRefs`、`certificateRefs`）。 | [28](28/tw.md) |
| **Replication configuration** | 將 images 複製至其他 regions/accounts 的 ECR rules；cross-account 時 receiving account 在 registry policy 允許 source `ecr:CreateRepository` 與 `ecr:ReplicateImage`。 | [20](20/tw.md) |
| **Repository creation template** | ECR 依 prefix 為 pull through cache 自動建立 repositories 時套用的 settings template（encryption、lifecycle、immutability、policy）；沒有它，cache repository 使用 defaults（`MUTABLE`、SSE-S3、無 policies）。 | [20](20/tw.md) |
| **Repository policy / registry policy** | 單一 repository 與整個 account registry 的 resource-based policies；可使用 `aws:PrincipalOrgID`，讓 pull 一次授予整個組織。 | [20](20/tw.md), [32](32/tw.md) |
| **requests** | 裝箱與 autoscaler 決策依據的 resources 數量；為 Pod 保留。 | [14](14/tw.md) |
| **resolveConflicts** | addon 遇到 field conflicts 時的行為：`NONE`、`OVERWRITE`、`PRESERVE`。 | [37](37/tw.md) |
| **Resource Modifiers** | 含 restore 時對 objects 套用 JSON patches 的 Velero ConfigMap（`--resource-modifier-configmap`）；用於移除不相容目標叢集的 fields。 | [42](42/tw.md) |
| **ResourceQuota / LimitRange** | 分別為 namespace 總 consumption 限制、以及單一 container defaults/limits。 | [22](22/tw.md) |
| **restore hook** | Velero restore Pod 時執行的 init-container 或 exec command。 | [42](42/tw.md) |
| **restore job** | AWS Backup restore task；以 `start-restore-job` 啟動、以 `list-restore-jobs`/`describe-restore-job` 追蹤。 | [42](42/tw.md) |
| **retention policy** | log group 中日誌的保存期，期限後 records 刪除；預設日誌不過期。 | [34](34/tw.md) |
| **right-sizing** | 調整 requests/limits 至實際 consumption，以提高 node 密度。 | [14](14/tw.md), [43](43/tw.md) |
| **rollback readiness** | 版本回滾準備度：已知期間與順序。 | [48](48/tw.md) |
| **rollback readiness insights** | `ROLLBACK_READINESS` 類別 cluster insights，檢查 rollback readiness；狀態 PASSING/WARNING/ERROR/UNKNOWN。 | [39](39/tw.md) |
| **Root 使用者** | 具無限權限的 account owner，僅在初始設定時需要。 | [0.1](00-1-aws/tw.md) |
| **Route 53 Resolver** | 位於「CIDR 加 2」位址的 VPC built-in DNS，為 CoreDNS upstream。 | [0.3](00-3-vpc/tw.md) |
| **Route table** | subnet routes table；public 與 private subnet 僅差在 default route。 | [0.3](00-3-vpc/tw.md) |
| **RPO** | 可接受的資料遺失量；由 backup frequency 設定。 | [42](42/tw.md) |
| **RTO** | 故障後 service 的目標復原時間。 | [42](42/tw.md) |
| **S3 Express One Zone** | 在單一 AZ 具低延遲和高 IOPS 的 zonal storage class（directory buckets）；不同於 general purpose buckets，支援 `append`。 | [25](25/tw.md) |
| **S3 Object Lock** | S3 bucket WORM protection：objects versions 在 retention 期間不可變（Governance/Compliance），保護 Velero backups 不被刪除與加密勒索。 | [42](42/tw.md) |
| **sampling** | 僅記錄一部分而非全部 traces，以控制量與成本。 | [36](36/tw.md) |
| **sampling rules** | 以 reservoir 與 fixed rate 設定記錄請求比例的 X-Ray rules。 | [36](36/tw.md) |
| **Savings Plans / RI** | 以 1 或 3 年承諾換取 30-70% 折扣。 | [0.4](00-4-ec2/tw.md) |
| **scale-to-zero** | 閒置時將 Deployment 降至零 replicas；KEDA 支援，HPA 不支援。 | [35](35/tw.md) |
| **ScaledJob** | KEDA CRD，依工作批次擴縮並行 Jobs 數量。 | [35](35/tw.md) |
| **ScaledObject** | KEDA CRD，描述 Deployment 的 scaling target 與 triggers。 | [35](35/tw.md) |
| **scaler** | KEDA metric source：`aws-sqs-queue`、`aws-cloudwatch`、`prometheus`、`kafka`、`cron` 等數十種。 | [35](35/tw.md) |
| **Schedule** | 用 cron 定期 backup 的 Velero object；設定 RPO。 | [42](42/tw.md) |
| **SCP (Service Control Policy)** | OU 或 account 的限制 policy：設定最大權限，本身不授權。 | [0.1](00-1-aws/tw.md), [0.2](00-2-iam/tw.md) |
| **Secondary CIDR** | VPC 的額外 IPv4 block；EKS 通常使用 `100.64.0.0/10`（RFC 6598）。 | [07](07/tw.md) |
| **Secrets Store CSI Driver + AWS provider (ASCP)** | 將 AWS secret 以 files mount 至 node volume 的 driver；使用 `SecretProviderClass` object，可選擇同步至 `Secret`。 | [18](18/tw.md) |
| **Security group** | ENI 上的 stateful firewall，僅 allow，source 可為另一個 SG。 | [0.3](00-3-vpc/tw.md), [46](46/tw.md) |
| **`SecurityGroupPolicy`** | 依 selector 將 SG 綁定 Pods（security groups for pods）的 resource；具 branch ENI 的 Pod 不再繼承 node SG rules。 | [46](46/tw.md) |
| **self-heal** | 自動將 drift 復原至 Git 中狀態。 | [44](44/tw.md) |
| **self-managed addon** | 以 Helm 或 manifest 安裝的元件；lifecycle 與 compatibility 全由 engineer 負責。 | [37](37/tw.md) |
| **Self-managed node** | 您自行建立並加入的 EC2 instance（`EC2_LINUX` 類型 access entry）；整個 node lifecycle 由您負責。 | [09](09/tw.md) |
| **service map** | 顯示 services 與其連線、edge latency 和 error ratio 的地圖。 | [36](36/tw.md) |
| **Service Network** | 一組 services 的 VPC Lattice boundary；client VPC 與其關聯即可存取 services。 | [28](28/tw.md) |
| **Service Quotas** | account 和 region 的 service limits，可申請提高。 | [0.1](00-1-aws/tw.md) |
| **`serviceIpv4Cidr`** | Service addresses 範圍，為虛擬且不連接 VPC。 | [06](06/tw.md) |
| **ServiceMonitor, PodMonitor** | Prometheus Operator CRD，宣告要 scrape 哪些 endpoints。 | [33](33/tw.md) |
| **Session tags** | Pod Identity 加入 STS 請求的 session tags（cluster、namespace、SA），用於 ABAC；policies 使用 `aws:PrincipalTag/kubernetes-namespace` 和 `aws:PrincipalTag/eks-cluster-name`；trust policy 需 `sts:TagSession`。 | [17](17/tw.md) |
| **shared costs** | 依規則分攤至團隊或獨立顯示的共用 cluster costs（control plane、system namespaces、idle）。 | [43](43/tw.md) |
| **Shared responsibility** | AWS 負責雲端的安全，您負責雲端中的安全。 | [0.1](00-1-aws/tw.md), [01](01/tw.md) |
| **shared services account** | 具有其他 accounts 使用之共用資源（ECR、private DNS zones、observability）的 account。 | [32](32/tw.md) |
| **shared VPC** | owner 透過 RAM 分享 subnets，其他 accounts 在其中執行自己的 resources（包括 EKS nodes）的模型。 | [32](32/tw.md) |
| **showback** | 向 teams 顯示其成本而不移動資金。 | [43](43/tw.md) |
| **SNAT** | 將 Pod egress source address 替換為 node address；以 `AWS_VPC_K8S_CNI_EXTERNALSNAT` 關閉。 | [06](06/tw.md) |
| **Soft multi-tenancy** | tenants 共用一個 cluster（namespace、RBAC、ResourceQuota、LimitRange、NetworkPolicy、policies）；共用 control plane 與 core。 | [22](22/tw.md) |
| **span** | trace 內一項操作（處理、呼叫、資料庫請求），具有時間與 attributes；spans 組成 trace tree。 | [36](36/tw.md) |
| **split-horizon DNS** | 透過一對 public/private zones，使同一名稱在 VPC 內外解析為不同答案。 | [29](29/tw.md) |
| **Spot interruption notice** | instance 停止或終止前兩分鐘的 interruption notice；是正常終止的嚴格時間限制。 | [13](13/tw.md) |
| **Spot instance** | 有折扣的閒置 EC2 capacity；AWS 隨時可能在 on-demand 需求需要時收回。 | [13](13/tw.md) |
| **Spot pool** | 「instance type + Availability Zone」組合；capacity 依 pool 回收。 | [13](13/tw.md) |
| **ssl-redirect** | 啟用 HTTP 至 listener 指定 port 的 HTTPS redirect 的 annotation。 | [27](27/tw.md) |
| **SSM Session Manager** | 經由 SSM agent、不使用 SSH 存取 instance。 | [45](45/tw.md) |
| **Staging labels** | Secrets Manager secret versions labels：預設讀取 `AWSCURRENT`，rotation 驗證中的是 `AWSPENDING`，前一版本是 `AWSPREVIOUS`。 | [18](18/tw.md) |
| **Stakater Reloader** | 當 mounted `Secret` 或 `ConfigMap` 變更時，依 annotation rolling restart Deployment 的 controller，使 Pod 取得新值。 | [18](18/tw.md) |
| **Standard support** | EKS Kubernetes minor 的支援階段（約 14 個月），正常運作且無版本額外費用。 | [03](03/tw.md), [38](38/tw.md), [48](48/tw.md) |
| **State** | Terraform code 與實際 resources 的對應檔；儲存於啟用 versioning 和 write locking 的 S3。 | [0.5](00-5-tools/tw.md), [04](04/tw.md) |
| **stdout/stderr** | container 的標準輸出 streams；Kubernetes 慣例是應用程式寫入它們，而非 container 內檔案。 | [34](34/tw.md) |
| **STS** | 暫時性 keys service；`sts:AssumeRole`、`sts:AssumeRoleWithWebIdentity`。 | [0.2](00-2-iam/tw.md) |
| **Subnet CIDR reservation** | 在 subnet 內保留連續 block 供 prefixes 使用。 | [07](07/tw.md) |
| **subnet IP exhaustion** | subnet 沒有可供 ENI 與 Pods 使用的 free addresses。 | [46](46/tw.md) |
| **sync waves** | Argo CD 在 sync phases 內按 waves 套用 resources 的順序。 | [44](44/tw.md) |
| **Tag immutability** | repository `IMMUTABLE` 模式，禁止以不同 image 覆寫 tag；`MUTABLE`（預設）允許覆寫。 | [20](20/tw.md) |
| **target EKS cluster** | 執行 restore 的既有 cluster；或由 AWS Backup 在 restore 期間建立（`newCluster=true`）。 | [42](42/tw.md) |
| **target-type** | NLB target 類型：`instance`（經 nodes `NodePort`）或 `ip`（直接 Pod IP，需要 VPC CNI，Fargate 必須使用）。 | [26](26/tw.md), [27](27/tw.md) |
| **`terminationGracePeriod`** | node drain 的上限；存在時，即使有阻擋的 PDB 與 `do-not-disrupt`，drift 仍會進行。 | [12](12/tw.md) |
| **terminationGracePeriodSeconds** | 結束 Pod 時 SIGTERM 與 SIGKILL 間的時間（預設 30）。 | [40](40/tw.md) |
| **terragrunt** | terraform wrapper：共用 backend、`env.hcl`、`dependency`、`run-all`、避免 copy-paste 的 DRY modules。 | [0.5](00-5-tools/tw.md) |
| **Thanos** | 為 Prometheus 加入 object storage 長期保存的一組元件：`sidecar` 將 blocks 匯出 S3，`store gateway` 讀回，`compactor` compact、downsample 並套用 retention，`querier` 提供統一 PromQL 和 HA pairs deduplication，`ruler` 計算歷史 rules。 | [33](33/tw.md) |
| **throughput mode** | EFS throughput 模式：Elastic、Bursting 或 Provisioned。 | [24](24/tw.md) |
| **topology aware routing** | 偏好 client 所在 zone 的 endpoints；以 Service `trafficDistribution: PreferClose` 欄位啟用。 | [31](31/tw.md) |
| **topologySpreadConstraints** | Pod 欄位，將 replicas 均勻分散至 domains（`maxSkew`、`topologyKey`、`whenUnsatisfiable`、`minDomains`）。 | [40](40/tw.md) |
| **trace** | 單一 request 經過 services 的完整路徑，共用 `trace id`。 | [36](36/tw.md) |
| **Transit Gateway** | 具已連接 VPC、VPN 與 Direct Connect 間 transitive routing 的 regional router hub；透過 RAM 分享。 | [32](32/tw.md) |
| **TriggerAuthentication** | 含 trigger access parameters 的 KEDA CRD；AWS 使用經由 IRSA 或 Pod Identity 的 `aws` provider。 | [35](35/tw.md) |
| **Trust policy** | role trust policy：`Federated` principal（OIDC provider ARN）、`Action` `sts:AssumeRoleWithWebIdentity`，以及對 `sub`、`aud` 的 `StringEquals` conditions。 | [0.2](00-2-iam/tw.md), [16](16/tw.md), [47](47/tw.md) |
| **TXT registry** | external-dns 機制，以 TXT marker 標記自己的 records；owner 由 `--txt-owner-id` 設定。 | [29](29/tw.md) |
| **Unauthorized (401)** | 驗證失敗：identity 未被證明或未映射。 | [47](47/tw.md) |
| **`unhealthyPodEvictionPolicy`** | PDB 欄位：`IfHealthyBudget`（預設）在應用已違反時不允許驅逐 unhealthy Pods，`AlwaysAllow` 永遠允許。 | [40](40/tw.md) |
| **upgrade insights** | 標示 upgrade readiness 與 removed APIs 的 insights 類型。 | [38](38/tw.md) |
| **Upgrade policy (`supportType`)** | 叢集設定欄位，值為 `STANDARD` 與 `EXTENDED`，決定 standard support 結束時的行為。Extended support 預設啟用；不可透過切換 policy 離開，只能升級。 | [03](03/tw.md) |
| **`useCachedMetrics` 與 `fallback`** | 在 polling interval 內快取值，以及 source unavailable 時的 replicas 數；共同降低 API throttling 與 `TARGETS` 中 `<unknown>` 的風險。 | [35](35/tw.md) |
| **User data** | instance 首次啟動執行的指令碼或 config；執行 bootstrap 並設定 `kubelet`。 | [0.4](00-4-ec2/tw.md), [10](10/tw.md) |
| **ValidatingAdmissionPolicy** | apiserver 內建 CEL validation（Kubernetes 1.30+），無 external webhook；搭配 `ValidatingAdmissionPolicyBinding`（套用目標與 `Deny`/`Warn`/`Audit` 回應）。 | [22](22/tw.md) |
| **Vault Lock** | 防止刪除 backups 的 vault WORM protection；governance mode（可經 IAM 移除）及 compliance mode（grace time 後不可變）。 | [41](41/tw.md) |
| **Velero** | Kubernetes-native backup/restore；objects 位於 S3（BackupStorageLocation），volumes 經 CSI snapshots 或 File System Backup。 | [42](42/tw.md) |
| **velero-plugin-for-aws** | AWS 官方 Velero plugin：用於 S3（BSL）的 object store 及 EBS snapshots 的 volume snapshotter。 | [42](42/tw.md) |
| **Version skew** | upstream policy 允許的 kubelet 相對 API server 落後程度；因此升級順序為「先 control plane，再 nodes」。 | [03](03/tw.md), [37](37/tw.md) |
| **version skew policy** | Kubernetes rule：nodes 不得新於 control plane；決定 rollback 順序（先 nodes，再 control plane）。 | [38](38/tw.md), [39](39/tw.md) |
| **VersionRollback** | rollback 時 `update-cluster-version` response 中的 update type。 | [39](39/tw.md) |
| **VictoriaLogs** | 無依賴、無 schema 和 index 設定的 log database；磁碟 columnar storage，以 LogsQL 查詢，接受 Elasticsearch bulk、Loki push、OTLP、syslog protocols；有 cluster variant（`vlinsert`、`vlstorage`、`vlselect`）。 | [34](34/tw.md) |
| **VictoriaMetrics** | metrics storage replacement 而非 add-on：`vmagent` 收集，`vmsingle` 或 `vminsert`/`vmstorage`/`vmselect` cluster，`vmalert` rules，`-retentionPeriod` 設 retention，MetricsQL 為 PromQL extension。 | [33](33/tw.md) |
| **volume node affinity conflict** | scheduler event：volume `nodeAffinity` 指向沒有符合 node 的 zone。 | [23](23/tw.md) |
| **`volumeBindingMode`** | volume 何時 provision：`Immediate`（PVC 出現時）或 `WaitForFirstConsumer`（Pod 排程時）。 | [23](23/tw.md) |
| **VolumeSnapshot / Content / Class** | CSI snapshots objects：request、AWS snapshot、class。 | [23](23/tw.md) |
| **voluntary disruption** | 有意識的 Pod eviction：drain、node upgrade、consolidation；由 PDB 保護。 | [40](40/tw.md) |
| **VPC** | region 中隔離的 network；主要 CIDR（`/16` ... `/28`）不可變，只能以 secondary CIDR 擴展。 | [0.3](00-3-vpc/tw.md) |
| **VPC CNI** | AWS network plugin，為 Pods 指派 VPC subnets 的真實 private addresses；`kube-system` 中的 `aws-node` DaemonSet。 | [06](06/tw.md) |
| **VPC CNI network policy** | `NetworkPolicy` 的內建 eBPF implementation：control plane controller 加 `aws-node` 中 `aws-network-policy-agent`；以 addon `enableNetworkPolicy` 參數啟用。 | [08](08/tw.md), [30](30/tw.md) |
| **VPC endpoint** | 私密存取 AWS service：gateway（S3、DynamoDB）或 interface（PrivateLink）。 | [0.3](00-3-vpc/tw.md), [31](31/tw.md) |
| **VPC endpoint (PrivateLink)** | VPC 內 AWS service 的 private entry point；private data node 必須具有 ECR、S3、STS、EKS 等 endpoints。 | [19](19/tw.md) |
| **VPC Flow Logs** | accepted 與 rejected flows 記錄；CloudWatch Logs Insights 中 `action = REJECT` filter 是 SecOps 與診斷工具。 | [0.3](00-3-vpc/tw.md) |
| **VPC Lattice** | 用於 VPC/account 間 east-west communication、無 sidecars 和 peering 的受管 application networking service。 | [28](28/tw.md) |
| **VPC peering** | 兩 VPC 間 one-to-one 直接連線；無 transitive，要求 CIDR 不重疊。 | [32](32/tw.md) |
| **wafv2-acl-arn** | 將 AWS WAF v2 Web ACL 關聯至 ALB 以過濾 requests 的 annotation。 | [27](27/tw.md) |
| **warm pool** | 為快速啟動 Pods 而預先分配至 node 的 IPv4 addresses 儲備。 | [06](06/tw.md) |
| **`WARM_PREFIX_TARGET`** | node 上預留 prefixes；`WARM_IP_TARGET` 和 `MINIMUM_IP_TARGET` 優先於它。 | [07](07/tw.md) |
| **workspace** | AMP 隔離 metrics storage，具自身 remote-write endpoint 與 Prometheus-compatible API。 | [33](33/tw.md) |
| **X-Amzn-Trace-Id** | 含 `Root`、`Parent`、`Sampled` fields 的 X-Ray header；ADOT X-Ray propagator 將它映射至 W3C `traceparent`，保留端到端 `trace id`。 | [36](36/tw.md) |
| **ZoneId (`euc1-az1`)** | 所有 accounts 中相同的穩定 Availability Zone 名稱。 | [0.1](00-1-aws/tw.md) |
| **`adot` 附加元件** | 部署 ADOT Operator 來管理 collectors 的 EKS managed addon。 | [36](36/tw.md) |
| **帳戶** | 隔離的 resources 空間與 billing unit；12 位數字參與 ARN 與 trust policy。 | [0.1](00-1-aws/tw.md) |
| **次要私有位址** | node ENI 上配發給 Pod 的額外 IPv4 address。 | [06](06/tw.md) |
| **多樣化** | 跨多個 AZ 的多種 instance types，避免單一 pool 回收移除關鍵 nodes 比例。 | [13](13/tw.md) |
| **就緒網域** | 獨立檢查的一個 operations axis（control plane、nodes、security、network、storage、observability、operations、incidents）。 | [48](48/tw.md) |
| **Drift（偏移）** | 實際狀態與 code 或 Git 描述狀態的不一致。 | [04](04/tw.md), [44](44/tw.md) |
| **stacks 之間的相依性** | 將一個 stack 的 outputs 傳入另一個 stack 的 inputs（Terragrunt 的 `dependency` block）。 | [04](04/tw.md) |
| **EC2 instance** | virtual machine；在 EKS 中是具 containerd 與 kubelet 的 node。 | [0.4](00-4-ec2/tw.md) |
| **local cache** | node volume 上 Mountpoint data cache（`cache: emptyDir`/`ephemeral`），加速重複讀取；metadata cache 以 `metadata-ttl` 設定。 | [25](25/tw.md) |
| **node scaling 與 Pod scaling** | 不同層次：CA 與 Karpenter 擴縮 nodes，HPA、VPA、KEDA 擴縮 Pods。 | [11](11/tw.md) |
| **micro-VM** | 單一 Pod 的專用 virtual machine，具自身 kernel、CPU、memory 與 network interface；Fargate isolation boundary。 | [15](15/tw.md) |
| **object storage** | key-value model：在 string key 下的 object（bytes 加 metadata），不可變，透過 `PutObject` 整體更新。 | [25](25/tw.md) |
| **rollback window（7 天）** | upgrade 後可回滾的期間；到期後 rollback 及其 insights 不可用。 | [39](39/tw.md) |
| **kubectl plugin** | `PATH` 中名為 `kubectl-<名稱>`、可作為 `kubectl <名稱>` 使用的檔案。 | [0.5](00-5-tools/tw.md) |
| **subnet** | 一個 AZ 中 VPC CIDR 的一部分。 | [0.3](00-3-vpc/tw.md) |
| **完全替換** | 移除 `aws-node`，Cilium 成為唯一 CNI，使用自身 IPAM：ENI IPAM（真實 VPC addresses）或 cluster-pool（overlay/VXLAN、virtual addresses）。 | [08](08/tw.md) |
| **prefix** | key 中 `/` 前的部分，Mountpoint 以其模擬目錄；S3 沒有真實目錄。 | [25](25/tw.md) |
| **強制 upgrade** | extended support 到期後自動提高版本；此類 cluster 無法 rollback。 | [38](38/tw.md) |
| **Provider** | terraform plugin（`aws`、`kubernetes`、`helm`）。 | [0.5](00-5-tools/tw.md) |
| **progressive delivery** | 應用程式 canary/blue-green deployment（Argo Rollouts、Flagger）。 | [44](44/tw.md) |
| **Production checklist** | 按 domains 系統性列出的 readiness checks；每項都已完成或標記為 known risk。 | [48](48/tw.md) |
| **Profile** | 名稱化 parameters 組合：region、role、SSO。 | [0.5](00-5-tools/tw.md) |
| **Region** | 資源所在的地理位置（`eu-central-1`）。 | [0.1](00-1-aws/tw.md) |
| **external 模式** | `aws-load-balancer-type` annotation 值，將 Service reconciliation 交給外部 LBC controller 而非 in-tree provider。 | [26](26/tw.md) |
| **EBS access modes** | `ReadWriteOnce`（一 node）與 `ReadWriteOncePod`（恰一 Pod）；`ReadWriteMany` 只可作為單一 AZ、無 filesystem、`volumeMode: Block` 的 Multi-Attach `io2`。共享 filesystem 使用 EFS 或 FSx。 | [23](23/tw.md) |
| **reconciliation** | 持續比對 desired（Git）與 actual（cluster）的迴圈。 | [44](44/tw.md) |
| **static provisioning** | 以 `bucketName` 手動描述 PV；driver 不支援 dynamic provisioning 或建立 buckets。 | [25](25/tw.md) |
| **Stack** | 可獨立套用、具有自身 state 的 infrastructure unit。 | [0.5](00-5-tools/tw.md), [04](04/tw.md) |
| **Rotation strategy** | `single user`（變更一位使用者密碼，存在短暫 failure risk window，以 delayed retries 緩解）或 `alternating users`（兩使用者輪替，隨時有有效 credentials，需要含 superuser 權限的 secret）。 | [18](18/tw.md) |
| **Spot strategy** | 選擇 pool 的方式：`capacity-optimized(-prioritized)` 對比 `lowest-price`；capacity-oriented 較少中斷。 | [0.4](00-4-ec2/tw.md) |
| **Tag** | key/value pair；EKS controllers 以 tags 找 resources，已啟用的 cost allocation tag 用於 billing 拆分帳單。 | [0.1](00-1-aws/tw.md) |
| **Instance type** | `family + generation + suffix . size`，例如 `m7g.xlarge`。 | [0.4](00-4-ec2/tw.md) |
| **control plane log 類型** | `api`、`audit`、`authenticator`、`controllerManager`、`scheduler`；僅在啟用後寫入 CloudWatch Logs。 | [02](02/tw.md) |
| **Argo CD 的 EKS managed capability** | 作為 EKS Capability 的 Argo CD：controllers 位於 AWS control plane，targets 僅能是以 ARN 指定的 EKS clusters，透過 EKS access entries 存取。 | [44](44/tw.md) |
| **kubernetes filter** | 加入 namespace、pod、container、labels 和 annotations 至 records 的 Fluent Bit FILTER。 | [34](34/tw.md) |
| **Argo CD sharding** | 將已連線 clusters 分配至 application-controller replicas。 | [44](44/tw.md) |
| **--force** | 略過 insights checks（ERROR/WARNING/UNKNOWN）的 flag，但不略過 prerequisites（window、one minor、created-on-version、feature compatibility）。 | [39](39/tw.md) |
| **/var/log/containers** | node 上指向 container log files 的目錄；collector 從此處取得 logs。 | [34](34/tw.md) |
