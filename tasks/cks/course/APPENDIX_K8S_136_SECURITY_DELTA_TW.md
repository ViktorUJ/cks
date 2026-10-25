[Русская версия](APPENDIX_K8S_136_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_136_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_136_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_136_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_136_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_136_SECURITY_DELTA_GE.md) · [日本語版](APPENDIX_K8S_136_SECURITY_DELTA_JP.md)

# 附錄。 Kubernetes v1.36 安全增量

> 標記：PRODUCTION / VERSION-SENSITIVE。包含在本附錄中並不表示某個主題屬於目前的 CKS 考試庫。課程的官方考試快照（請參閱[`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)）使用Kubernetes v1.35，而課程訓練基線是v1.36。在將每個項目視為考試事實之前檢查每個項目：一些更改在生產中很重要，但課程可能會落後於次要版本。

本附錄是主要課程章節的補充。它將與安全相關的 Kubernetes v1.36 更改收集在一個地方，而不是將它們分散到所有 33 個章節中，或者將生產當前性與考試保真度混淆。

## 1. User Namespaces GA

**CKS 相關性：** Deep Dive / 生產。

- `spec.hostUsers: false` 將 Pod 放置在使用者命名空間：容器內的 root 對應到主機上的非特權 UID。
- 這是額外的縱深防禦邊界，而不是現有控制的替代（功能，seccomp、AppArmor、RBAC）。請參閱[第 03 章](03/tw.md)。
- 僅Linux；請參閱第 03 章以了解特定限制（原始塊卷、NFS）。

## 2. Fine-Grained Kubelet API Authorization GA

**CKS 相關性：** 核心（用於[第 05 章](05/tw.md)）。

- 此前，`nodes/proxy`是幾乎所有kubeletAPI路徑的唯一子資源，包括看似安全的`/metrics`和危險的`/exec`。
- GA 引入獨立的子資源：`nodes/stats`、`nodes/metrics`、`nodes/log`、`nodes/pods`、`nodes/healthz`、`nodes/configz`、`nodes/spec`、`nodes/checkpoint`。
- 對於 `/pods`、`/runningPods/`、`/healthz` 和 `/configz`，kubelet 首先檢查細粒度子資源，並在拒絕向後相容性時回退到 `nodes/proxy`。
- **為什麼這對安全審查很重要：** 帶有 `nodes/proxy GET` 的監控代理可以透過節點上任何容器中的 RCE 的 kubelet API WebSocket 語義來濫用。 `GET`映射到RBAC`get`，但是`kubelet`不會單獨檢查`create`進行後續的寫入操作。請參閱第 05 章及其「攻擊者的觀點」部分。
- 資料來源：[Kubernetes v1.36 部落格 - Fine-Grained Kubelet API Authorization 畢業生到 GA](https://kubernetes.io/blog/2026/04/24/kubernetes-v1-36-fine-grained-kubelet-authorization-ga/)。

## 3. 修改/驗證准入政策 GA 和Manifest-Based Admission Control（alpha）

**CKS 相關性：** VAP 核心（用於 [第 20 章](20/tw.md)）；Manifest-Based Admission Control 是Deep Dive（alpha，預設為停用）。

- 基於本機CEL的策略層減少了許多常見規則對額外准入 Webhook 的需求。它不會取代 Kyverno/Gatekeeper 進行產生、複雜物件突變或供應鏈影像驗證（請參閱第 20 章和第 26 章）。
- Manifest-Based Admission Control（v1.36，alpha）支援靜態准入物件：所有物件的名稱都必須以 `.static.k8s.io` 結尾；繫結中禁止使用 `paramRef`；靜態 webhook 僅允許 `clientConfig.url`，不允許 `clientConfig.service`。無效的靜態 manifest 可能導致 API 伺服器無法就緒。

## 4. Service.spec.externalIPs 正式棄用

**CKS 相關性：** 產量/Deep Dive。

- `externalIPs` 在 Kubernetes v1.36 中正式棄用。未來的次要版本預計將從 kube-proxy 中刪除該行為，並從一致性標準中刪除其支援要求。
- **安全原因：** 該領域長期以來一直存在風險：能夠創建/編輯 Services 的非特權用戶可以在沒有所有權驗證的情況下聲明任意 IP。這會在多租戶群集中產生 MITM 風險，並與 **CVE-2020-8554** （使用 LoadBalancer 或外部 IP 的中間人）直接相關。
- **目前替代方案：** 透過雲端/本地控制器或網關 API LoadBalancer Service，而不是直接使用 `externalIPs`。
- 來源：[Kubernetes v1.36 部落格 - 棄用與刪除 Service 外部 IP](https://v1-36.docs.kubernetes.io/blog/2026/05/14/kubernetes-v1-36-deprecation-and-removal-of-service-externalips/)、[CVE-2020-8554 諮詢](https://discuss.kubernetes.io/t/security-advisory-cve-2020-8554-man-in-the-middle-using-loadbalancer-or-externalips/14003)。

## 5. gitRepo卷永久禁用

**CKS 相關性：** 生產/Deep Dive（供應鏈/可變源課程）。

- `gitRepo` 卷類型在 Kubernetes v1.36 中**永久停用**，且無法透過功能閘門重新啟用。 Kubernetes API 仍接受具有 `gitRepo` 卷的 Pod，但 kubelet 拒絕啟動它並返回錯誤。
- **安全性原因：** `gitRepo` 磁碟機在節點上的 kubelet 託管進程內運行 `git clone`，沒有足夠的隔離。因此，特製的 Git 儲存庫可能會在 `git clone` 期間透過寫入掛鉤導致 RCE。
- **供應鏈教訓：** 在配置期間執行任意外部程式碼的磁碟區類型（甚至「只是」`git clone`）與沒有摘要固定的可變影像標籤具有相同等級的風險。信任在運作時轉移到外部、不完全控制的來源，而不是事先進行驗證。
- 來源：[AWS EKS 發行說明 - gitRepo 磁碟區刪除](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions-standard.html)、[kubernetes/kubernetes#125983 - 刪除 gitRepo 磁碟區類型](https://github.com/kubernetes/kubernetes/issues/125983)。

## 6. SELinux 卷標更改（安裝時重新標記）

**CKS 相關性：** Deep Dive（用於[第 18 章](18/tw.md)）。

- 容器運行時而不是 kubelet 執行遞歸 SELinux 重新標記。
- 對於存取模式不是 `ReadWriteOncePod` 的 PVC，掛載時重新標記（`-o context=`）需要啟用 `SELinuxMount` 功能閘門（v1.36 預設停用），且對應的 CSI 驅動程式必須設定 `CSIDriver.spec.seLinuxMount: true`。否則會使用較慢的遞迴重新標記。
- 請參閱第 18 章以了解遞歸重新標記和 `MountOption` 之間的差異。

## 如何使用本附錄

在講課或考試準備中引用某項作為「當前事實」之前：

1. 檢查[`metadata/tool-compatibility.yaml`](../metadata/tool-compatibility.yaml)和[`metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)中的`checked_at`。
2. 檢查特定功能是否在目前課程中（`CKS_Curriculum` PDF）。不要假設生產當前自動意味著與考試相關。
3. 如果某個項目在實驗室或章節中用作*核心*材料（請參閱[`metadata/curriculum-map.yaml`](../metadata/curriculum-map.yaml)），請使其此處和該章節中的措辭保持同步。

---
[內容](README_TW.md)
