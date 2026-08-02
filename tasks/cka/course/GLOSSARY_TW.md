[Русская версия](GLOSSARY_RU.md) · [Eng version](GLOSSARY.md) · [Versión en español](GLOSSARY_ES.md) · [Version française](GLOSSARY_FR.md) · [Deutsche Version](GLOSSARY_DE.md) · [ქართული ვერსია](GLOSSARY_GE.md) · [日本語版](GLOSSARY_JP.md)

# CKA + CKAD 課程詞彙表

[← 課程目錄](README_TW.md) · [CKA](CKA_TW.md) · [CKAD](CKAD_TW.md)

課程術語的統一字母順序參考。術語用英文(與 Kubernetes 一致),說明用繁體中文,
「章節」欄顯示該術語在哪裡講解(附章節連結)。頁內搜尋 - Ctrl+F。

| 術語 | 說明 | 章節 |
|--------|----------|-------|
| **A 記錄 / AAAA 記錄** | DNS 記錄:名稱 → IPv4 / 名稱 → IPv6。 | [0.2](00-2-dns/tw.md) |
| **accessModes** | 存取模式:RWO、ROX、RWX、RWOP。 | [25](25/tw.md) |
| **activeDeadlineSeconds** | 任務的最長執行時間。 | [10](10/tw.md) |
| **Adapter** | 把應用的輸出轉換成所需格式的容器。 | [22](22/tw.md) |
| **admin.conf** | init 之後的管理員 kubeconfig。 | [35](35/tw.md) |
| **Admission control** | 在 authn+authz 之後對請求做檢查/修改。 | [21](21/tw.md) |
| **aggregation layer** | 透過自己的 extension-apiserver 擴充 API(例如 metrics-server)。 | [41](41/tw.md) |
| **APIService** | 註冊聚合 API 的物件(`metrics.k8s.io` 等)。 | [41](41/tw.md) |
| **allow 邏輯** | 政策只做允許;沒有「拒絕」這種獨立規則。 | [34](34/tw.md) |
| **allowPrivilegeEscalation** | 允許/禁止提升權限。 | [20](20/tw.md) |
| **allowVolumeExpansion** | 是否允許擴充卷。 | [25](25/tw.md), [26](26/tw.md) |
| **Ambassador** | 為應用的外送連線做中介的容器。 | [22](22/tw.md) |
| **Annotation** | 存放附加資料的鍵值對,不用於選取。 | [06](06/tw.md) |
| **API deprecation** | 宣告某個 API 版本過時,之後將被移除。 | [29](29/tw.md) |
| **apiVersion** | 物件所屬 API 群組的版本(alpha/beta/穩定版)。 | [29](29/tw.md) |
| **Application container** | Pod 中承載業務負載的主容器。 | [04](04/tw.md) |
| **apply** | 依清單建立或更新物件(冪等,3-way merge)。 | [03](03/tw.md) |
| **args** | 覆寫映像的 CMD(參數)。 | [17](17/tw.md) |
| **Authn** | 確認請求的發送者是誰。 | [21](21/tw.md) |
| **Authz** | 檢查發送者是否被允許(RBAC)。 | [21](21/tw.md) |
| **automountServiceAccountToken** | 是否把 SA 的 token 掛載進 Pod。 | [21](21/tw.md) |
| **averageUtilization** | 資源負載的目標平均百分比。 | [16](16/tw.md) |
| **backendRefs** | 目標 Service(canary 時帶權重)。 | [33](33/tw.md) |
| **backoffLimit** | 失敗時的重試次數。 | [10](10/tw.md) |
| **Bare pod** | 直接建立、沒有控制器的 Pod;不會被重建。 | [04](04/tw.md) |
| **base** | 共用的原始清單。 | [43](43/tw.md) |
| **Base image** | 建置起點的基礎映像(`FROM`)。 | [23](23/tw.md) |
| **base64** | Secret 值的編碼方式;不是加密。 | [19](19/tw.md) |
| **behavior** | 對 scale up/down 速度的精細調整。 | [16](16/tw.md) |
| **Binding** | 把合適的 PV 與 PVC 綁定(一對一)。 | [25](25/tw.md) |
| **Blue** | 目前執行中的版本;**Green** - 準備切換過去的新版本。 | [09](09/tw.md) |
| **Blue/Green** | 兩套完整環境(現行與新版),流量瞬間切換。 | [09](09/tw.md) |
| **bootstrap token** | 節點 join 用的臨時 token(存活約 24 小時)。 | [35](35/tw.md) |
| **bridge (cni0)** | 節點上的軟體交換器,連接該節點上的 Pod。 | [0.7](00-7-netns/tw.md), [30](30/tw.md) |
| **CA** | 憑證頒發機構;信任的根,負責簽發憑證。 | [0.3](00-3-tls/tw.md), [39](39/tw.md) |
| **Calico / Cilium / Flannel** | 常見的 CNI 外掛。 | [30](30/tw.md), [40](40/tw.md) |
| **Canary** | 先把新版本發布給少量流量,再逐步放大。 | [09](09/tw.md) |
| **CIDR** | `位址/N` 的寫法,其中 `N` 是網路位元數;N 越大,網路越小。 | [0.1](00-1-net/tw.md), [30](30/tw.md) |
| **CNAME** | DNS 記錄:指向另一個名稱的別名。 | [0.2](00-2-dns/tw.md) |
| **capabilities** | 從「root 全能」中拆出的單項權限(drop/add)。 | [20](20/tw.md) |
| **cgroups** | 限制容器資源的核心控制器(cpu、memory、pids、io);requests/limits 的基礎。 | [0.4](00-4-containers/tw.md), [14](14/tw.md) |
| **cgroup v1 / v2** | 舊版(每個控制器一套階層)/ 新版(單一階層)的 cgroups;自 Fedora 31、Ubuntu 22.04、Debian 11、RHEL 9 起 v2 為預設(K8s 的 cgroup v2 自 1.25 GA)。 | [0.4](00-4-containers/tw.md) |
| **cgroup 驅動** | 由誰設定 cgroups(`systemd` 或 `cgroupfs`);kubelet 與 runtime 必須一致(`SystemdCgroup=true`)。 | [0.4](00-4-containers/tw.md), [35](35/tw.md) |
| **cert-manager** | 自動簽發與續期憑證的 operator。 | [32](32/tw.md) |
| **cert-manager / Prometheus Operator** | 常見的 operator。 | [41](41/tw.md) |
| **change-cause** | 記錄變更原因、供查看歷史的註解。 | [08](08/tw.md) |
| **Chart** | 套件:清單模板 + values + 中繼資料。 | [42](42/tw.md) |
| **CKA** | Certified Kubernetes Administrator,叢集管理方向的考試。 | [01](01/tw.md) |
| **CKAD** | Certified Kubernetes Application Developer,應用執行方向的考試。 | [01](01/tw.md) |
| **Client certificate** | 使用者的身分憑證;CN → 名稱,O → 群組。 | [39](39/tw.md) |
| **Cluster Autoscaler** | 改變叢集中的節點數量。 | [16](16/tw.md) |
| **Karpenter** | 為 Pending 的 Pod 挑選並啟動所需類型的節點(比 Cluster Autoscaler 更靈活)。 | [16](16/tw.md) |
| **Cluster API** | 以宣告式方式管理叢集的生命週期。 | [35](35/tw.md), [35B](35-3-design/tw.md) |
| **managed / self-managed** | control plane 由供應商託管(EKS/GKE/AKS)/ 由你自己維運。 | [35B](35-3-design/tw.md) |
| **node pool** | 同類型節點的群組(規格、可用區、spot/on-demand)。 | [35B](35-3-design/tw.md) |
| **IaC** | 基礎設施即程式碼(Terraform/OpenTofu、Ansible)。 | [35B](35-3-design/tw.md) |
| **GitOps** | 以 git 作為叢集狀態的唯一真實來源(Argo CD/Flux)。 | [35B](35-3-design/tw.md) |
| **cluster-admin / admin / edit / view** | 內建的 ClusterRole。 | [38](38/tw.md) |
| **Cluster-scoped 物件** | 叢集層級的物件(Node、PV、StorageClass、ClusterRole)。 | [06](06/tw.md) |
| **ClusterIP** | 預設類型:內部虛擬 IP,只能在叢集內存取。 | [07](07/tw.md) |
| **ClusterRole** | 叢集層級 / cluster-scoped 資源的權限,或供重複使用。 | [38](38/tw.md) |
| **ClusterRoleBinding** | 在整個叢集範圍把角色綁定到主體。 | [38](38/tw.md) |
| **CNCF** | Cloud Native Computing Foundation,Kubernetes 與這些認證背後的組織。 | [01](01/tw.md) |
| **CNI** | Pod 網路的介面與外掛(Calico、Cilium 等)。 | [02](02/tw.md), [30](30/tw.md), [40](40/tw.md) |
| **command** | 覆寫映像的 ENTRYPOINT(要執行什麼)。 | [17](17/tw.md) |
| **completions** | 需要幾次成功完成。 | [10](10/tw.md) |
| **componentstatuses** | 元件狀態總覽(逐步廢棄中)。 | [45](45/tw.md) |
| **concurrencyPolicy** | CronJob 執行重疊時的策略(Allow/Forbid/Replace)。 | [10](10/tw.md) |
| **Conditions** | 節點的狀態(Ready、MemoryPressure、DiskPressure、PIDPressure)。 | [45](45/tw.md) |
| **ConfigMap** | 存放非機密設定的物件(鍵值或檔案)。 | [18](18/tw.md) |
| **configMapGenerator / secretGenerator** | 產生 ConfigMap/Secret(名稱帶雜湊)。 | [43](43/tw.md) |
| **configMapKeyRef** | 把 ConfigMap 的單一鍵取為環境變數。 | [18](18/tw.md) |
| **container runtime** | 容器的執行環境(containerd),透過 CRI 通訊。 | [02](02/tw.md) |
| **containerd / CRI-O** | CRI 的實作(runtime)。 | [40](40/tw.md) |
| **context** | cluster + user + namespace 的組合。 | [39](39/tw.md) |
| **Context (kubeconfig)** | 叢集 + 使用者 + namespace 的組合;用 `use-context` 切換。 | [03](03/tw.md) |
| **Control plane** | 叢集的管理層(大腦):apiserver、etcd、scheduler、controller-manager。 | [02](02/tw.md) |
| **Controller** | 帶有調諧迴圈的程式(把現實收斂到 spec)。 | [41](41/tw.md) |
| **cordon** | 把節點標記為 unschedulable(新 Pod 不再排到這裡)。 | [36](36/tw.md) |
| **cordon / drain** | 把節點標記為 unschedulable / 把 Pod 從節點上驅逐(第 36 章)。 | [13](13/tw.md), [36](36/tw.md) |
| **CoreDNS** | 叢集的 DNS 伺服器(kube-system 中的 Deployment,前面是 Service kube-dns)。 | [31](31/tw.md) |
| **Corefile** | CoreDNS 的設定(放在 ConfigMap `coredns`)。 | [31](31/tw.md) |
| **CrashLoopBackOff** | 容器反覆崩潰並重啟。 | [04](04/tw.md), [44](44/tw.md) |
| **containerd / CRI-O** | kubelet 直接對接的高階 container runtime。 | [0.4](00-4-containers/tw.md), [40](40/tw.md) |
| **CRD** | 在 API 中定義新的物件類型。 | [41](41/tw.md) |
| **CreateContainerConfigError** | Pod 引用的 ConfigMap/Secret 不存在。 | [44](44/tw.md) |
| **CRI** | kubelet ↔ 執行環境之間的介面。 | [0.4](00-4-containers/tw.md), [40](40/tw.md) |
| **crictl** | 在節點上透過 CRI 操作容器的 CLI。 | [40](40/tw.md), [45](45/tw.md) |
| **CronJob** | 依 cron 排程建立 Job。 | [10](10/tw.md) |
| **CSI** | 把儲存接入 Kubernetes 的標準。 | [26](26/tw.md), [40](40/tw.md) |
| **CSI 驅動** | CSI 的實作(StorageClass 中的 provisioner)。 | [40](40/tw.md) |
| **CSR** | 透過叢集 API 提出的憑證簽署請求。 | [39](39/tw.md) |
| **certSANs** | apiserver 憑證中的附加名稱/位址(例如 HA 用的負載平衡器 DNS)。 | [35](35/tw.md) |
| **certificatesDir** | 叢集 PKI 的目錄(預設 `/etc/kubernetes/pki`)。 | [35](35/tw.md) |
| **Custom Resource** | 由 CRD 定義的類型的實例。 | [41](41/tw.md) |
| **custom-columns** | 自訂的輸出表格。 | [47](47/tw.md) |
| **DaemonSet** | 在每個(符合條件的)節點上維持一個 Pod 的控制器。 | [11](11/tw.md) |
| **data / binaryData** | ConfigMap 的文字 / 二進位資料。 | [18](18/tw.md) |
| **Declarative approach** | 透過清單管理(`kubectl apply -f`)。 | [01](01/tw.md), [03](03/tw.md) |
| **default / kube-system / kube-public / kube-node-lease** | 系統 namespace。 | [06](06/tw.md) |
| **default deny** | 依方向阻擋全部流量的政策(沒有允許規則)。 | [34](34/tw.md) |
| **default SA** | 每個 namespace 裡的預設 ServiceAccount。 | [21](21/tw.md) |
| **Default StorageClass** | 給未指定 class 的 PVC 使用的預設類別。 | [26](26/tw.md) |
| **default-deny + DNS** | 陷阱:egress 政策切斷了名稱解析(第 34 章)。 | [34](34/tw.md), [46](46/tw.md) |
| **Deployment** | ReplicaSet 之上的控制器:副本 + 更新 + 回滾 + 歷史。 | [05](05/tw.md) |
| **Desired state** | 你在清單裡描述的狀態。 | [01](01/tw.md) |
| **Destructive operations** | etcd restore、drain:要格外仔細檢查。 | [48](48/tw.md) |
| **distroless / scratch** | 去掉多餘內容的最小基礎映像 / 完全空的映像。 | [23](23/tw.md) |
| **dnsConfig** | 對 Pod DNS 的細部設定(含 `options ndots`),在任何 dnsPolicy 下都有效。 | [31](31/tw.md) |
| **dnsPolicy** | Pod 如何取得 DNS(ClusterFirst 等)。 | [31](31/tw.md) |
| **Dockerfile** | 建置映像的指令。 | [0.4](00-4-containers/tw.md), [23](23/tw.md) |
| **Downward API** | Pod 取得自身資訊的途徑(`fieldRef`、`resourceFieldRef`)。 | [17](17/tw.md) |
| **drain** | 把 Pod 從節點優雅驅逐,轉移到其他節點。 | [36](36/tw.md) |
| **Dynamic provisioning** | 依 PVC 的請求自動建立 PV。 | [26](26/tw.md) |
| **eBPF** | Linux 核心中的技術,Cilium 以它為基礎。 | [30](30/tw.md) |
| **EmptyDir** | 供 Pod 內容器交換檔案的卷。 | [22](22/tw.md), [24](24/tw.md) |
| **encryption at rest** | etcd 中 Secret 的加密。 | [19](19/tw.md) |
| **External CA mode** | `pki/` 中只有 `ca.crt` 而沒有私鑰:kubeadm 產生 CSR,簽署與續期由你負責。 | [35](35/tw.md) |
| **endpoint 2379** | etcd 的用戶端連接埠。 | [37](37/tw.md) |
| **Endpoints** | Service 背後 Pod 位址的清單;為空 = 沒有綁定(第 7 章)。 | [07](07/tw.md), [46](46/tw.md) |
| **Endpoints / EndpointSlice** | Service 背後已就緒 Pod 的 IP 清單。 | [07](07/tw.md) |
| **ENTRYPOINT/CMD** | 映像中定義的執行內容與參數。 | [17](17/tw.md) |
| **env** | 容器的環境變數。 | [17](17/tw.md) |
| **envFrom + configMapRef** | 把 ConfigMap 的所有鍵作為環境變數。 | [18](18/tw.md) |
| **Ephemeral volume** | 與 Pod 同壽(能撐過容器重啟,但 Pod 被刪除就消失)。 | [24](24/tw.md) |
| **ephemeral 容器** | 用來除錯執行中 Pod 的臨時容器(`kubectl debug`)。 | [04](04/tw.md), [29](29/tw.md) |
| **etcd** | 保存整個叢集狀態的分散式 key-value 儲存。 | [02](02/tw.md), [37](37/tw.md) |
| **etcdctl** | 操作 etcd 的 CLI;做快照需要 `ETCDCTL_API=3`。 | [37](37/tw.md) |
| **Events** | `describe`/`get events` 輸出中物件的動作時間軸。 | [29](29/tw.md), [44](44/tw.md) |
| **eviction** | 節點資源不足時 kubelet 驅逐 Pod。 | [14](14/tw.md) |
| **exec** | 在容器內執行命令/shell。 | [29](29/tw.md) |
| **exec 形式** | 以列表形式給出命令,不經 shell(訊號處理正確)。 | [17](17/tw.md) |
| **expandtab** | 為 YAML 準備的 vim 設定(用空格取代 tab)。 | [0.8](00-8-vim/tw.md), [47](47/tw.md) |
| **External Secrets / Vault / SOPS / Sealed Secrets** | 真正保護機密資料的工具。 | [19](19/tw.md) |
| **ExternalName** | 指向外部網域的 DNS 別名(CNAME)。 | [07](07/tw.md) |
| **FailedScheduling** | Pending 時排程器產生的事件。 | [44](44/tw.md) |
| **failureThreshold / successThreshold** | 切換狀態所需的失敗/成功次數。 | [27](27/tw.md) |
| **filters** | 轉換(rewrite、redirect、標頭)。 | [33](33/tw.md) |
| **Flat network** | 任一 Pod 都能直接用 IP 看到任一 Pod,不經 NAT。 | [30](30/tw.md) |
| **Fluent Bit/Fluentd** | 日誌收集代理(通常以 DaemonSet 部署)。 | [28](28/tw.md) |
| **Service 的 FQDN** | `<service>.<namespace>.svc.cluster.local`。 | [31](31/tw.md) |
| **fsGroup** | 已掛載卷的擁有者群組(Pod 層級)。 | [20](20/tw.md) |
| **Gateway** | 入口點:listener(連接埠、協定、TLS);由叢集維運者負責。 | [33](33/tw.md) |
| **Gateway API** | Kubernetes 中現代的流量路由標準。 | [33](33/tw.md) |
| **FQDN** | 包含所有層級的完整網域名稱(例如 `backend.default.svc.cluster.local`)。 | [0.2](00-2-dns/tw.md), [31](31/tw.md) |
| **GatewayClass** | Gateway API 的實作(控制器),類似 StorageClass。 | [33](33/tw.md) |
| **globalDefault** | 套用到未指定優先級 Pod 的 PriorityClass。 | [15](15/tw.md) |
| **HA (high availability)** | control plane 的容錯:多個節點,單一節點故障不會讓管理面停擺。 | [35A](35-2-ha/tw.md) |
| **--control-plane-endpoint** | HA 用的 control plane 穩定位址(負載平衡器);在 `kubeadm init` 時指定。 | [35A](35-2-ha/tw.md), [35](35/tw.md) |
| **stacked / external etcd** | etcd 跑在 control-plane 節點上(預設)/ 跑在獨立節點上。 | [35A](35-2-ha/tw.md) |
| **quorum (etcd)** | etcd 寫入所需的多數節點(raft);因此節點數為奇數(3/5)。 | [35A](35-2-ha/tw.md), [37](37/tw.md) |
| **leader election** | 在 HA 中選出作用中的 scheduler/controller-manager 實例(其餘待命)。 | [35A](35-2-ha/tw.md) |
| **SPOF** | 單一故障點;HA 消除它。 | [35A](35-2-ha/tw.md) |
| **--upload-certs / certificate-key** | HA 節點 join 時傳遞 control plane 的憑證。 | [35A](35-2-ha/tw.md) |
| **Handshake (TLS)** | 建立 TLS 連線的流程(驗證憑證、協商金鑰)。 | [0.3](00-3-tls/tw.md) |
| **Headless Service** | `clusterIP: None`,DNS 直接回傳 Pod 的 IP。 | [07](07/tw.md), [11](11/tw.md) |
| **Helm** | Kubernetes 的套件管理器。 | [42](42/tw.md) |
| **helm install/upgrade/rollback/uninstall** | release 的生命週期。 | [42](42/tw.md) |
| **helm template** | 在本機把 chart 渲染成清單(用於檢查)。 | [42](42/tw.md) |
| **hostPath** | 把節點的目錄掛載進 Pod(有風險,適用於系統類任務)。 | [24](24/tw.md) |
| **HPA** | 依指標改變副本數量。 | [16](16/tw.md) |
| **httpGet / tcpSocket / exec / grpc** | 檢查的方式。 | [27](27/tw.md) |
| **HTTPRoute** | 導向 Service 的 HTTP 路由規則;由開發者負責。 | [33](33/tw.md) |
| **IgnoredDuringExecution** | 規則只在排程時檢查,不會驅逐已啟動的 Pod。 | [12](12/tw.md) |
| **Image** | 打包好的應用檔案系統 + 依賴 + 啟動中繼資料。 | [23](23/tw.md) |
| **ImagePullBackOff/ErrImagePull** | 無法下載映像。 | [44](44/tw.md) |
| **imagePullPolicy** | 何時拉取映像(IfNotPresent/Always/Never)。 | [23](23/tw.md) |
| **imagePullSecrets** | 存取私有映像倉庫用的 Secret。 | [19](19/tw.md) |
| **immutable** | 不可變的 ConfigMap(只能重新建立)。 | [18](18/tw.md) |
| **Imperative approach** | 用命令管理物件(`kubectl run`、`create`)。 | [01](01/tw.md), [03](03/tw.md) |
| **Ingress 控制器** | 實際執行 Ingress 規則的應用(nginx、Traefik、ALB)。 | [32](32/tw.md) |
| **Ingress 資源** | L7 路由規則的宣告(主機、路徑、TLS)。 | [32](32/tw.md) |
| **ingress2gateway** | 把 Ingress 自動轉成 Gateway API 資源的工具(產出草稿,需人工審閱)。 | [33](33/tw.md) |
| **IngressClass** | 由哪個控制器服務這個 Ingress(`ingressClassName`)。 | [32](32/tw.md) |
| **Init 容器** | 在主容器之前執行、且必須結束的容器。 | [22](22/tw.md) |
| **initialDelaySeconds** | 首次檢查前的延遲。 | [27](27/tw.md) |
| **IP 位址** | 裝置在網路中的數字位址(IPv4 - 32 位元,四個位元組)。 | [0.1](00-1-net/tw.md) |
| **ipBlock** | 依 IP 範圍放行(外部流量)。 | [34](34/tw.md) |
| **iptables / IPVS 模式** | Service 的實作方式;IPVS 擴展性更好。 | [31](31/tw.md) |
| **Job** | 一次性任務的控制器;負責確認 Pod 成功結束。 | [10](10/tw.md) |
| **journalctl -u kubelet** | kubelet 的日誌,查 NotReady 原因的首要來源。 | [45](45/tw.md) |
| **JSONPath** | 從 API 回應中選取欄位的語言(`-o jsonpath=...`)。 | [03](03/tw.md), [47](47/tw.md) |
| **KEDA** | 依外部事件做事件驅動自動擴縮(可縮到零)。 | [16](16/tw.md) |
| **kube-apiserver** | 所有請求的唯一入口;也是唯一寫入 etcd 的元件。 | [02](02/tw.md) |
| **list-watch** | 追蹤變更:LIST + WATCH 串流(不輪詢 API)。 | [02](02/tw.md) |
| **informer** | 控制器的本機物件快取,透過 watch 同步。 | [02](02/tw.md) |
| **resourceVersion** | 物件的版本;watch 續傳與樂觀鎖的基礎。 | [02](02/tw.md) |
| **樂觀鎖** | 用過期版本寫入會被拒絕(409 Conflict)→ 重試。 | [02](02/tw.md) |
| **kube-controller-manager** | 一組控制器(調諧迴圈)。 | [02](02/tw.md) |
| **kube-proxy** | 在節點上透過 iptables/IPVS 實現 Service。 | [02](02/tw.md), [07](07/tw.md), [31](31/tw.md) |
| **kube-scheduler** | 把 Pod 指派到節點。 | [02](02/tw.md), [12](12/tw.md) |
| **kubeadm** | 官方的叢集安裝工具(init/join/upgrade)。 | [35](35/tw.md) |
| **kubeadm certs renew** | 更新叢集的憑證。 | [39](39/tw.md) |
| **kubeadm init** | 初始化 control plane。 | [35](35/tw.md) |
| **kubeadm join** | 把節點加入叢集。 | [35](35/tw.md) |
| **kubeadm reset** | 清除節點上的 kubeadm 狀態。 | [36](36/tw.md) |
| **kubeadm upgrade plan / apply / node** | 計畫 / 套用(第一個 CP)/ 更新節點。 | [36](36/tw.md) |
| **kubeconfig** | 存放叢集、使用者與 context 的檔案(`~/.kube/config`)。 | [03](03/tw.md), [39](39/tw.md) |
| **kubectl** | 操作叢集的主要命令列工具。 | [01](01/tw.md), [03](03/tw.md) |
| **kubectl apply -k** | 套用 Kustomize 目錄。 | [43](43/tw.md) |
| **kubectl certificate approve** | 核准 CSR(由 CA 簽署)。 | [39](39/tw.md) |
| **kubectl debug** | 注入除錯容器 / 複製 Pod / 除錯節點。 | [29](29/tw.md) |
| **kubectl explain** | 物件欄位的內建文件。 | [03](03/tw.md) |
| **kubectl kustomize / kustomize build** | 只渲染,不套用。 | [43](43/tw.md) |
| **kubectl logs** | 查看 Pod/容器的日誌。 | [28](28/tw.md) |
| **kubectl top** | 顯示資源用量(需要 metrics-server)。 | [28](28/tw.md) |
| **kubelet** | 節點上的代理,啟動並監管 Pod;是系統服務。 | [02](02/tw.md) |
| **Kubernetes** | 容器編排系統:把叢集的實際狀態收斂到期望狀態。 | [01](01/tw.md) |
| **kustomization.yaml** | 描述資源與轉換的檔案。 | [43](43/tw.md) |
| **Kustomize** | 以套用補丁調整清單的工具,不用模板。 | [43](43/tw.md) |
| **Label** | 用於選取與關聯物件的鍵值對。 | [06](06/tw.md) |
| **Labels** | 物件上的鍵值對,選擇器依它們運作。 | [05](05/tw.md) |
| **Layer** | 一組檔案系統變更;層會被快取並重複使用。 | [23](23/tw.md) |
| **Layered troubleshooting** | 由下而上排查網路:CNI → DNS → Endpoints → 政策 → 入口。 | [46](46/tw.md) |
| **LimitRange** | namespace 內單個物件的資源預設值與上下限。 | [14](14/tw.md) |
| **limits** | 用量的上限;執行期間強制。 | [14](14/tw.md) |
| **liveness** | 容器是否還活著;失敗 → 重啟。 | [27](27/tw.md) |
| **LoadBalancer** | Service 前面的外部雲端負載平衡器。 | [07](07/tw.md) |
| **localhost** | Pod 的共用網路,容器之間藉此互相看到。 | [22](22/tw.md) |
| **Manifest** | 描述 Kubernetes 物件的 YAML 檔案。 | [01](01/tw.md) |
| **matchLabels / matchExpressions** | 選擇器的兩種寫法。 | [06](06/tw.md) |
| **maxSurge** | 滾動更新期間可以超出期望數量的 Pod 數。 | [08](08/tw.md) |
| **maxUnavailable** | 滾動更新期間可以暫時失去的 Pod 數。 | [08](08/tw.md) |
| **medium: Memory** | 把 emptyDir 放在 RAM(tmpfs)。 | [24](24/tw.md) |
| **metrics-server** | 收集 Pod 的 CPU/記憶體;HPA 與 `kubectl top` 需要它。 | [16](16/tw.md), [28](28/tw.md) |
| **Mi/Gi vs M/G** | 二進位(1024)與十進位(1000)的記憶體單位。 | [14](14/tw.md) |
| **Microsegmentation** | 對 Pod/Service 之間流量的細緻劃分。 | [34](34/tw.md) |
| **milli-CPU** | 一核的千分之一(`500m` = 半核)。 | [14](14/tw.md) |
| **minReplicas/maxReplicas** | 副本數量的下限與上限。 | [16](16/tw.md) |
| **Mirror Pod** | static pod 在 API 中的映射;看得到,但不能用 kubectl 刪除。 | [15](15/tw.md) |
| **Mock exam** | 帶計時與自動評分的模擬演練。 | [48](48/tw.md) |
| **mTLS** | 雙向 TLS:雙方都要出示憑證。 | [0.3](00-3-tls/tw.md), [39](39/tw.md) |
| **Multi-stage build** | 在一個映像中建置,最終只留下產出。 | [23](23/tw.md) |
| **Mutating / Validating admission** | 修改型 / 驗證型的控制器。 | [21](21/tw.md) |
| **Namespace** | 叢集的分區;物件名稱在其中唯一。 | [06](06/tw.md) |
| **Namespaced 物件** | 存在於 namespace 之中(Pod、Deployment、Service...)。 | [06](06/tw.md) |
| **namespaceSelector** | 依 namespace 的標籤選取 Pod。 | [34](34/tw.md) |
| **NAT** | 在閘道上替換位址,讓私有流量能連到外部。 | [0.1](00-1-net/tw.md) |
| **netshoot** | 內含網路工具的除錯映像。 | [46](46/tw.md) |
| **NetworkPolicy** | 規定哪個 Pod 能與哪個通訊的規則(Pod 層級的防火牆)。 | [34](34/tw.md) |
| **Node** | 叢集中的機器(VM 或實體機)。 | [02](02/tw.md) |
| **Node-level work** | SSH + systemctl/journalctl/crictl/etcdctl(CKA 的特點)。 | [48](48/tw.md) |
| **nodeAffinity** | 靈活的節點選取;`required`(硬性)與 `preferred`(柔性)。 | [12](12/tw.md) |
| **NodeLocal DNSCache** | 每個節點上的本機 DNS 快取。 | [31](31/tw.md) |
| **nodeName** | 繞過排程器,硬指定節點。 | [12](12/tw.md) |
| **NodePort** | 在所有節點上開啟連接埠(30000-32767)供外部存取。 | [07](07/tw.md) |
| **nodeSelector** | 依節點標籤做簡單的硬性選取。 | [12](12/tw.md) |
| **NoExecute** | 不排程,並驅逐已在執行且沒有 toleration 的 Pod。 | [13](13/tw.md) |
| **NoSchedule** | 不排程沒有 toleration 的新 Pod(既有的留下)。 | [13](13/tw.md) |
| **NotReady** | kubelet 沒有回報就緒時的節點狀態。 | [45](45/tw.md) |
| **ndots** | 名稱中點數的門檻:少於它時,名稱會先配合 search 後綴嘗試(預設 `ndots:5` → 外部名稱會產生多餘查詢)。 | [31](31/tw.md) |
| **namespaces (Linux)** | 隔離行程所看到的內容:PID、NET、MNT、UTS、IPC、USER(不要與 Kubernetes 的 namespace 混淆)。 | [0.4](00-4-containers/tw.md) |
| **network namespace** | 行程/容器獨立的網路堆疊(自己的介面、IP、路由)。 | [0.7](00-7-netns/tw.md), [40](40/tw.md) |
| **nslookup/dig** | 從 Pod 內部檢查 DNS 解析。 | [46](46/tw.md) |
| **OCI** | 映像與容器格式的開放標準(Docker ↔ containerd 的相容性)。 | [0.4](00-4-containers/tw.md) |
| **OLM** | Operator Lifecycle Manager,安裝/更新 operator 的機制。 | [41](41/tw.md) |
| **OOMKilled** | 容器因超出記憶體限制而被殺掉。 | [04](04/tw.md), [14](14/tw.md), [44](44/tw.md) |
| **Operator** | 控制器 + 管理某個應用的領域知識。 | [41](41/tw.md) |
| **operator Equal/Exists** | 依值比對 / 只比對鍵。 | [13](13/tw.md) |
| **Orchestration** | 自動管理容器的生命週期(啟動、重啟、擴縮、放置)。 | [01](01/tw.md) |
| **overlay** | 針對特定環境疊在 base 之上的變更集。 | [43](43/tw.md) |
| **Overlay network** | 節點之間對封包做封裝的網路(VXLAN)。 | [30](30/tw.md) |
| **parallelism** | Job 同時啟動多少個 Pod。 | [10](10/tw.md) |
| **parentRefs** | 把 Route 綁定到 Gateway。 | [33](33/tw.md) |
| **Partial credit** | 部分完成也會計分。 | [47](47/tw.md) |
| **patches** | 對欄位的局部修改(strategic merge / JSON6902)。 | [43](43/tw.md) |
| **pathType** | 路徑比對的方式:Prefix / Exact / ImplementationSpecific。 | [32](32/tw.md) |
| **pause 容器** | 持有 Pod 網路 namespace 的輔助容器。 | [40](40/tw.md) |
| **Pending** | Pod 沒有被排程(資源/taints/affinity/PVC)。 | [44](44/tw.md) |
| **periodSeconds** | 檢查的間隔。 | [27](27/tw.md) |
| **PersistentVolume** | 叢集中代表「一塊儲存」的物件。 | [25](25/tw.md) |
| **PersistentVolumeClaim** | 應用對儲存的申請(容量、模式)。 | [25](25/tw.md) |
| **Phase** | Pod 生命的大階段:Pending、Running、Succeeded、Failed、Unknown。 | [04](04/tw.md) |
| **叢集 PKI** | `/etc/kubernetes/pki/` 中的 CA 與憑證集合,在 `kubeadm init` 時建立。 | [35](35/tw.md), [39](39/tw.md) |
| **front-proxy-ca** | 給 aggregation layer(API 伺服器擴充)用的 CA。 | [35](35/tw.md) |
| **sa.key / sa.pub** | 簽署 ServiceAccount token 的金鑰對。 | [35](35/tw.md), [21](21/tw.md) |
| **pluto / kubent** | 在清單/叢集中尋找過時 API 的工具。 | [29](29/tw.md), [36](36/tw.md) |
| **kubepug (kubectl deprecations)** | 針對目標 K8s 版本檢查 API(叢集與檔案)。 | [29](29/tw.md) |
| **kubeconform** | 依目標 K8s 版本的 schema 驗證清單(CI)。 | [29](29/tw.md) |
| **Popeye** | 叢集的健檢工具;也會找出過時的 API。 | [29](29/tw.md) |
| **Pod** | 最小的執行單位:包住一個或多個容器、共用網路與卷的外殼。 | [04](04/tw.md) |
| **Pod CIDR / Service CIDR** | Pod 位址範圍 / Service 虛擬 IP 範圍;兩者不得重疊。 | [0.1](00-1-net/tw.md), [30](30/tw.md) |
| **Pod connectivity** | Pod 之間能否用 IP 通訊(CNI 層級,第 30 章)。 | [30](30/tw.md), [46](46/tw.md) |
| **Pod Security Admission** | 內建的 privileged/baseline/restricted 層級政策。 | [20](20/tw.md) |
| **podAffinity** | 把 Pod 放在帶有指定標籤的 Pod 附近。 | [12](12/tw.md) |
| **podAntiAffinity** | 把 Pod 放在遠離帶有指定標籤的 Pod。 | [12](12/tw.md) |
| **PodDisruptionBudget** | 自願驅逐時可用 Pod 的最小數量。 | [36](36/tw.md) |
| **podSelector** | 政策套用到哪些 Pod / 放行哪些。 | [34](34/tw.md) |
| **policyTypes** | 方向:Ingress(入站)與/或 Egress(出站)。 | [34](34/tw.md) |
| **port / targetPort / nodePort** | Service 的連接埠 / Pod 上的連接埠 / 節點上的連接埠。 | [07](07/tw.md) |
| **port-forward** | 把 Pod/Service 的連接埠轉發到本機。 | [29](29/tw.md), [46](46/tw.md) |
| **Preemption** | 刪除優先級較低的 Pod,以便放置優先級較高的。 | [15](15/tw.md) |
| **PreferNoSchedule** | 柔性地避免排到這裡。 | [13](13/tw.md) |
| **pressure-taints** | 節點資源不足時自動加上的 taint(第 13 章)。 | [13](13/tw.md), [45](45/tw.md) |
| **PriorityClass** | 帶有 Pod 數值優先級的物件。 | [15](15/tw.md) |
| **privileged** | 特權容器(≈ 節點上的 root);危險。 | [20](20/tw.md) |
| **Probe** | 由 kubelet 執行的容器健康檢查。 | [27](27/tw.md) |
| **Progressive delivery** | 依指標自動化的 canary/blue-green(Argo Rollouts、Flagger)。 | [09](09/tw.md) |
| **projected** | 合併多個來源的卷(secret/configMap/downwardAPI)。 | [24](24/tw.md) |
| **Prometheus / Grafana** | 指標的收集/儲存與視覺化(真正的監控)。 | [28](28/tw.md) |
| **provisioner** | 建立實際卷的 CSI 驅動。 | [26](26/tw.md) |
| **PTR** | 反向 DNS 記錄:IP → 名稱。 | [0.2](00-2-dns/tw.md) |
| **QoS 類別** | Guaranteed / Burstable / BestEffort;記憶體不足時的驅逐順序。 | [14](14/tw.md) |
| **Quorum** | etcd 運作所需的多數節點(HA)。 | [37](37/tw.md) |
| **raft** | etcd 節點之間達成一致的共識協定。 | [02](02/tw.md) |
| **RBAC** | 基於角色的存取控制(第 38 章)。 | [21](21/tw.md), [38](38/tw.md) |
| **readiness** | 是否準備好接收流量;失敗 → 從 Endpoints 移除(不重啟)。 | [27](27/tw.md) |
| **readOnlyRootFilesystem** | 根檔案系統設為唯讀。 | [20](20/tw.md) |
| **ReadWriteMany** | 從多個節點讀寫(需要網路檔案系統)。 | [25](25/tw.md) |
| **ReadWriteOnce** | 從單一節點讀寫(不是單一 Pod!)。 | [25](25/tw.md) |
| **reclaimPolicy** | PVC 被刪除後 PV 的命運:Retain / Delete。 | [25](25/tw.md) |
| **Reconciliation loop** | 控制器持續消除期望狀態與實際狀態差異的迴圈。 | [01](01/tw.md) |
| **Recreate** | 「先全部刪掉,再建立」的策略;會有停機。 | [08](08/tw.md) |
| **Registry** | 映像的倉庫(預設是 Docker Hub);私有倉庫需要 imagePullSecret。 | [0.4](00-4-containers/tw.md), [23](23/tw.md) |
| **Release** | 已安裝的 chart 實例(帶修訂歷史)。 | [42](42/tw.md) |
| **replicas** | 期望的 Pod 數量。 | [05](05/tw.md) |
| **ReplicaSet** | 依選擇器維持指定 Pod 數量的控制器。 | [05](05/tw.md) |
| **ReplicationController** | ReplicaSet 的過時前身。 | [05](05/tw.md) |
| **Repository** | chart 的倉庫。 | [42](42/tw.md) |
| **requests** | 保證的最小資源;排程時會用到。 | [14](14/tw.md) |
| **required vs preferred** | affinity 中嚴格(必須)與柔性(盡量)的放置規則。 | [12](12/tw.md) |
| **ResourceQuota** | namespace 內資源總量與物件數量的上限。 | [14](14/tw.md) |
| **restartPolicy** | 容器的重啟策略:Always、OnFailure、Never。 | [04](04/tw.md) |
| **Return to context** | 在節點上操作完之後,回到原本的機器繼續。 | [48](48/tw.md) |
| **Revision** | 歷史中固定下來的 Deployment 模板版本。 | [08](08/tw.md) |
| **revisionHistoryLimit** | 保留多少個舊 ReplicaSet 以供回滾。 | [08](08/tw.md) |
| **Role** | 單一 namespace 內的權限。 | [38](38/tw.md) |
| **RoleBinding** | 在 namespace 內把角色綁定到主體。 | [38](38/tw.md) |
| **roleRef** | binding 引用的是哪個角色。 | [38](38/tw.md) |
| **rollback** | 回滾到前一個修訂(`rollout undo`)。 | [08](08/tw.md) |
| **RollingUpdate** | 逐步替換 Pod、不停機的策略(預設)。 | [08](08/tw.md) |
| **rollout** | Deployment 發布新版本的過程。 | [08](08/tw.md) |
| **Routed network** | 直接知道通往 Pod 路由的網路(BGP)。 | [30](30/tw.md) |
| **rules** | 允許對什麼做什麼。 | [38](38/tw.md) |
| **runAsNonRoot** | 禁止以 root 執行。 | [20](20/tw.md) |
| **runAsUser / runAsGroup** | 容器行程的 UID/GID。 | [20](20/tw.md) |
| **runc** | 透過核心啟動容器的低階工具。 | [0.4](00-4-containers/tw.md), [40](40/tw.md) |
| **Scheduler Profiles** | 同一個排程器內的多套設定。 | [15](15/tw.md) |
| **schedulerName** | 由哪個排程器來安排這個 Pod。 | [15](15/tw.md) |
| **scope** | CRD 的範圍:在 namespace 內或整個叢集。 | [41](41/tw.md) |
| **search 網域** | resolv.conf 中補全短名稱的後綴。 | [0.2](00-2-dns/tw.md), [31](31/tw.md) |
| **Secret** | 存放敏感資料的物件(密碼、token、金鑰、憑證)。 | [19](19/tw.md) |
| **secretKeyRef / secretRef** | 把某個鍵/整個 Secret 接進 env。 | [19](19/tw.md) |
| **SecurityContext** | Pod/容器層級的安全設定。 | [20](20/tw.md) |
| **selector** | 控制器如何找到「自己的」Pod(依標籤)。 | [05](05/tw.md), [06](06/tw.md) |
| **Selector switch** | 改變 Service 的 `selector`,把流量瞬間切到另一個版本(blue/green 的基礎)。 | [09](09/tw.md) |
| **SSH** | 透過網路安全登入節點;`exit` - 返回。 | [0.5](00-5-linux/tw.md) |
| **sudo** | 以 root 身分執行命令;`sudo -i` - 在整個工作階段成為 root。 | [0.5](00-5-linux/tw.md) |
| **systemd / systemctl** | 服務管理系統(kubelet、containerd)與對應的命令。 | [0.5](00-5-linux/tw.md), [45](45/tw.md) |
| **Service** | 一組依選擇器挑出的 Pod 前面的穩定位址與負載平衡。 | [07](07/tw.md) |
| **ServiceAccount** | Pod/行程存取 API 的身分。 | [21](21/tw.md) |
| **shell 形式** | 透過 `sh -c` 執行命令(需要變數、管線時使用)。 | [17](17/tw.md) |
| **Sidecar** | 同一 Pod 內的輔助容器(第 22 章)。 | [04](04/tw.md), [22](22/tw.md) |
| **snapshot restore** | 把快照展開到新的資料目錄。 | [37](37/tw.md) |
| **snapshot save** | 把 etcd 備份成檔案。 | [37](37/tw.md) |
| **stabilization window** | 縮減副本前的等待窗口。 | [16](16/tw.md) |
| **Stable identity** | 可預測、且能撐過重建的 Pod 名稱(`db-0`、`db-1`)。 | [11](11/tw.md) |
| **startup** | 啟動是否完成;未通過前會阻擋其他探針。 | [27](27/tw.md) |
| **Stateful** | 有狀態的應用;需要身分與自己的儲存。 | [05](05/tw.md) |
| **StatefulSet** | 有狀態應用的控制器:穩定名稱、順序、每個 Pod 自己的儲存。 | [11](11/tw.md) |
| **Stateless** | 沒有唯一狀態的應用;Pod 可以互換。 | [05](05/tw.md) |
| **Static Pod** | 由 kubelet 直接依 `/etc/kubernetes/manifests/` 中的清單啟動的 Pod,不經排程器。 | [02](02/tw.md), [15](15/tw.md), [45](45/tw.md) |
| **staticPodPath** | kubelet 監看的目錄(通常是 `/etc/kubernetes/manifests/`)。 | [15](15/tw.md) |
| **stdout/stderr** | 容器的標準輸出,Kubernetes 從這裡取日誌。 | [28](28/tw.md) |
| **StorageClass** | 建立卷的模板:provisioner、參數、reclaim 政策。 | [26](26/tw.md) |
| **stringData** | 以純文字填值的欄位(會自動編碼)。 | [19](19/tw.md) |
| **subjects** | 把權限給誰:User、Group、ServiceAccount。 | [38](38/tw.md) |
| **suspend** | 暫時停用 CronJob。 | [10](10/tw.md) |
| **swapoff** | 關閉 swap(Kubernetes 的要求)。 | [35](35/tw.md) |
| **Taint** | 節點上排斥 Pod 的限制標記(`鍵=值:效果`)。 | [13](13/tw.md) |
| **Task weight** | 分數的占比,優先順序的提示。 | [47](47/tw.md) |
| **TCPRoute / gRPCRoute / TLSRoute** | 其他協定的路由。 | [33](33/tw.md) |
| **template** | 建立副本所依據的 Pod 模板。 | [05](05/tw.md) |
| **Three pillars of observability** | 日誌、指標、追蹤。 | [28](28/tw.md) |
| **Three-pass strategy** | 時間策略:先簡單 → 再困難 → 最後檢查。 | [47](47/tw.md), [48](48/tw.md) |
| **throttling** | 超出 CPU 限制時對容器降速。 | [14](14/tw.md) |
| **TLS** | 加密並驗證流量的協定(HTTPS 中的「S」)。 | [0.3](00-3-tls/tw.md) |
| **TLS termination** | 在 Ingress 解密 HTTPS;憑證來自 tls 類型的 Secret。 | [0.3](00-3-tls/tw.md), [32](32/tw.md) |
| **Toleration** | Pod 的「通行證」,讓它可以待在有 taint 的節點上。 | [13](13/tw.md) |
| **tolerationSeconds** | Pod 在帶 NoExecute 的節點上被驅逐前能停留多久。 | [13](13/tw.md) |
| **topologyKey** | 決定「鄰近區域」的節點標籤(hostname、zone)。 | [12](12/tw.md) |
| **topologySpreadConstraints** | 讓 Pod 依拓撲平均分布(`maxSkew`)。 | [12](12/tw.md) |
| **troubleshooting 領域** | 占 CKA 的 30%,權重最高;修應用/叢集/網路。 | [48](48/tw.md) |
| **TTL** | DNS 記錄在快取中的存活時間(秒)。 | [0.2](00-2-dns/tw.md) |
| **ttlSecondsAfterFinished** | 已完成的 Job 在指定時間後自動刪除。 | [10](10/tw.md) |
| **type** | Secret 的用途(Opaque、tls、dockerconfigjson 等)。 | [19](19/tw.md) |
| **uncordon** | 讓節點回到可排程的池子裡。 | [36](36/tw.md) |
| **updateStrategy** | DaemonSet/StatefulSet 的更新策略(rolling)。 | [11](11/tw.md) |
| **valueFrom** | 從來源填入變數(Pod 欄位、資源、CM/Secret)。 | [17](17/tw.md) |
| **Values** | 代入模板的參數。 | [42](42/tw.md) |
| **VAR** | 在清單中引用先前宣告過的變數。 | [17](17/tw.md) |
| **veth pair** | 兩個相連的虛擬介面 - Pod 與節點 network namespace 之間的「網線」。 | [0.7](00-7-netns/tw.md), [30](30/tw.md) |
| **Version skew** | 元件版本允許的差距;kubelet 不可比 apiserver 新。 | [36](36/tw.md) |
| **Volume** | 在 Pod 層級宣告、並掛載進容器的儲存。 | [24](24/tw.md) |
| **Volume mount** | ConfigMap 的鍵變成目錄中的檔案。 | [18](18/tw.md) |
| **volumeBindingMode** | 何時建立/綁定卷(Immediate / WaitForFirstConsumer)。 | [26](26/tw.md) |
| **volumeClaimTemplates** | StatefulSet 為每個 Pod 建立 PVC 的模板。 | [11](11/tw.md), [26](26/tw.md) |
| **volumes / volumeMounts** | 卷的宣告 / 把它掛載進容器。 | [24](24/tw.md) |
| **VPA** | 改變 Pod 的 requests/limits。 | [16](16/tw.md) |
| **webhook** | 對物件的外部檢查/修改(Kyverno、OPA、mesh)。 | [21](21/tw.md) |
| **YAML** | 人類可讀的清單格式;層級用縮排表示(只能用空格)。 | [0.6](00-6-yaml/tw.md), [03](03/tw.md) |
| **whenUnsatisfiable** | topologySpread 的模式:`DoNotSchedule`(嚴格,→ Pending)或 `ScheduleAnyway`(柔性,容許偏斜)。 | [12](12/tw.md) |
| **Worker 節點** | 執行應用 Pod 的工作節點。 | [02](02/tw.md) |
| **Ingress 註解** | 控制器專屬的設定(rewrite、timeout 等)。 | [32](32/tw.md) |
| **非對稱加密** | 一對相關聯的金鑰:私鑰(機密)與公鑰(公開)。 | [0.3](00-3-tls/tw.md) |
| **子網路遮罩** | 位址中哪一部分屬於網路,哪一部分屬於主機。 | [0.1](00-1-net/tw.md) |
| **位元組(octet)** | IPv4 位址中四個數字之一(8 位元,0-255)。 | [0.1](00-1-net/tw.md) |
| **連接埠** | 0-65535 的數字,指出裝置上的應用;「IP + 連接埠」= 服務端點。 | [0.1](00-1-net/tw.md) |
| **私鑰 / 公鑰** | 擁有者的機密金鑰(不外傳)/ 公開金鑰(發給所有人)。 | [0.3](00-3-tls/tw.md) |
| **解析器(resolver)** | 代替應用執行 DNS 查詢的元件(叢集中是 CoreDNS)。 | [0.2](00-2-dns/tw.md), [31](31/tw.md) |
| **憑證** | 公鑰 + 擁有者資料 + CA 簽章。 | [0.3](00-3-tls/tw.md), [39](39/tw.md) |
| **Ingress → Gateway API 遷移** | 把一個 Ingress 拆成 Gateway(入口)+ HTTPRoute(規則)。 | [33](33/tw.md) |
| **原生 sidecar** | 帶 `restartPolicy: Always` 的 init 容器。 | [22](22/tw.md) |
| **etcd 憑證** | `/etc/kubernetes/pki/etcd/` 中的 CA/cert/key。 | [37](37/tw.md) |
| **Kubernetes 網路模型** | 對網路的要求:Pod 有自己的 IP、通訊不經 NAT、扁平網路。 | [30](30/tw.md) |
| **PV/PVC 狀態** | Available、Bound、Pending、Released。 | [25](25/tw.md) |
| **標籤(tag)/ digest** | 映像的版本 / 內容的不可變雜湊。 | [23](23/tw.md) |

## 參數、旗標與代碼

命令的旗標、輔助別名與回應代碼 - 從主要的字母術語清單中分開列出。

| 參數 / 代碼 | 說明 | 章節 |
|----------------|----------|-------|
| **$do / $now** | 輔助別名 `--dry-run=client -o yaml` / 快速刪除。 | [47](47/tw.md) |
| **--control-plane-endpoint** | control plane 的共用位址(HA 用)。 | [35](35/tw.md) |
| **--data-dir** | etcd 的資料目錄(restore 時要用新的)。 | [37](37/tw.md) |
| **--from-file / --from-env-file** | 整個檔案放進一個鍵 / 逐行放進多個鍵。 | [18](18/tw.md) |
| **--ignore-daemonsets** | drain 時不動 DaemonSet 的 Pod(它們綁在節點上)。 | [36](36/tw.md) |
| **--pod-network-cidr** | Pod 的位址範圍(要與 CNI 一致)。 | [35](35/tw.md) |
| **--previous** | 前一個(已崩潰)容器的日誌。 | [28](28/tw.md) |
| **--set / -f** | 在 CLI 覆寫 values / 用檔案覆寫。 | [42](42/tw.md) |
| **401 vs 403** | 未通過驗證(憑證)vs 沒有權限(RBAC)。 | [39](39/tw.md) |
| **`--dry-run=client -o yaml`** | 產生 YAML,但不建立任何東西。 | [03](03/tw.md) |
