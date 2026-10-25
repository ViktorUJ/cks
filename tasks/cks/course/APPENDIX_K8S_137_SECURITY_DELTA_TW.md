[Русская версия](APPENDIX_K8S_137_SECURITY_DELTA_RU.md) · [Eng version](APPENDIX_K8S_137_SECURITY_DELTA.md) · [Versión en español](APPENDIX_K8S_137_SECURITY_DELTA_ES.md) · [Version française](APPENDIX_K8S_137_SECURITY_DELTA_FR.md) · [Deutsche Version](APPENDIX_K8S_137_SECURITY_DELTA_DE.md) · [ქართული ვერსია](APPENDIX_K8S_137_SECURITY_DELTA_GE.md) · [日本語版](APPENDIX_K8S_137_SECURITY_DELTA_JP.md)

# 附錄。 Kubernetes v1.37 安全增量

> 標記：PRODUCTION / VERSION-SENSITIVE。包含在本附錄中並不表示某個主題屬於目前的 CKS 考試庫。課程的官方考試快照（請參閱[`../metadata/cks-exam-snapshot.yaml`](../metadata/cks-exam-snapshot.yaml)）使用Kubernetes v1.35，而課程訓練基線是v1.36。最新的上游穩定版本是Kubernetes v1.37。在未單獨確認其考試/課程相關性的情況下，請勿將本附錄中的功能推廣到 🎯 CKS Core。

本附錄彙整 Kubernetes v1.37 的安全相關變更。主要章節與實驗仍以已驗證的考試及訓練環境為準；此處記錄目前生產環境的版本差異。

## 1. Manifest-Based Admission Control：測試版，預設啟用

**CKS 相關性：** Deep Dive / 生產 / 版本敏感。

在 v1.36 訓練基準中，Manifest-Based Admission Control 仍為 alpha，且預設停用。在 v1.37 中，此功能進入 Beta，`ManifestBasedAdmissionControlConfig` 功能閘門預設啟用。API 伺服器會從靜態檔案載入 webhook 和基於 CEL 的准入政策：這些政策在 API 伺服器啟動時即生效，無須依賴 etcd 儲存准入設定本身，並可保護透過 API 管理的准入資源免遭修改。

這彌補了啟動與自我保護的缺口，但也增加操作風險：初次載入無效的 manifest 會導致 API 伺服器無法就緒。在 HA 環境中，每個 API 伺服器都讀取自己的檔案，因此必須以一致且不可分割的方式交付設定。

來源：[Manifest-Based Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/manifest-admission-control/)。

## 2. SELinuxMount：GA並預設啟用

**CKS 相關性：** Deep Dive / 生產 / 版本敏感。

v1.36 的 `SELinuxMount` 預設停用；v1.37 則已 GA 並預設啟用。對於符合條件的 CSI PVC，只有在 `CSIDriver.spec.seLinuxMount: true` 且其他適用條件均滿足時，Kubernetes 才使用 SELinux 標籤掛載選項，取代較慢的遞迴重新標記。此行為變更意味著：同一節點上共用磁碟區的 Pod 若使用不相容的 SELinux 標籤，可能停留在 `ContainerCreating`。

在升級啟用 SELinux 的叢集之前，請啟用 `SELinuxWarningController`、解決偵測到的衝突並觀察其指標。有意跨不同標籤共享磁碟區的工作負載可以使用以下方法保留先前的行為：

```yaml
spec:
  securityContext:
    seLinuxChangePolicy: Recursive
```

來源：[為 Pod 或容器設定安全上下文](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/)。

## 3. Pod Certificates和ClusterTrustBundles：穩定

**CKS 相關性：** Deep Dive / 生產。

ServiceAccount JWT 仍是 bearer credential：token 受到有效期限、物件繫結與 audience 限制，但會出示給對端。Pod Certificates 新增具有私密金鑰與金鑰持有證明模型的 X.509 工作負載憑證。Kubelet 建立 `PodCertificateRequest`，向簽署者取得憑證鏈並輪替憑證；憑證與信任套件會透過投射磁碟區（projected volumes）提供給工作負載。`ClusterTrustBundle` 提供信任錨點。

簽署者的實作仍可替換。Kubernetes v1.37 並未提供適用於 SPIFFE 或所有工作負載的通用內建簽署者。因此，Pod Certificates 不會自動取代 ServiceAccount JWT，也不會讓既有的 Istio/SPIFFE 身分機制變得多餘。

來源：[Kubernetes v1.37：Pod Certificates 和叢集信任捆綁包](https://kubernetes.io/blog/2026/08/28/kubernetes-v1-37-pod-certificates-and-cluster-trust-bundles/)。

## 4. KubeletInUserNamespace：Beta 無根節點路徑

**CKS 相關性：** Deep Dive / 生產。

`KubeletInUserNamespace` 在 v1.37 為 Beta。啟用後，kubelet、CRI/OCI runtime、CNI 與 kube-proxy 可以在 Linux 使用者命名空間內，以主機上的非 root 使用者執行。這種 rootless 節點架構可降低節點元件遭入侵的影響，但可能需要檢查 CNI 與 CSI 的相容性。

不要將它與 `spec.hostUsers: false` 混淆：後者為 Pod 建立使用者命名空間，而節點元件仍可能以主機 root 身分執行。這是不同且可併用的安全邊界。啟用功能閘門不會自動將既有的 rootful 節點轉為 rootless 模式。

來源：[Kubernetes v1.37：KubeletInUserNamespace 升級至 Beta](https://kubernetes.io/blog/2026/09/04/kubernetes-v1-37-rootless-beta/)。

## 5. 刪除不可讀取/損壞的資源：不安全的復原路徑

**CKS 相關性：** 生產 / 復原 / 危險操作。

在 v1.37 中，Beta 版預設啟用功能閘門`AllowUnsafeMalformedObjectDeletion` 允許不安全地刪除因解密失敗或解碼損壞而無法從儲存讀取的物件。刪除請求使用`ignoreStoreReadErrorWithClusterBreakingPotential`；需要 `delete` 和 `unsafe-delete-ignore-read-errors` 權限。

> ⚠️ 這是最後手段的復原機制，可能破壞叢集。它略過 finalizer 與前置條件檢查，不能取代舊加密金鑰的保留或備份/還原，也不是修正 EncryptionConfiguration 錯誤的一般方法。

來源：[KubernetesAPI概念：強制刪除](https://kubernetes.io/docs/reference/using-api/api-concepts/#force-deletion)。

## 6. StorageVersionMigration：GA 並預設啟用

**CKS 相關性：** 生產 / Deep Dive。

在 v1.37 中，內建 `storagemigration.k8s.io/v1` API 和控制器成為 GA 並預設為啟用。 Storage Version Migration 以宣告方式將持久化的 API 物件重寫到目前儲存版本中。這對於 API 儲存版本遷移非常有用，並且可以構成加密提供者或金鑰變更後受控重新加密的一部分。

SVM 不等於加密提供者輪替：提供者順序、舊資料解密、備份與還原策略仍是操作人員的個別責任。

來源：[Kubernetes v1.37：預設啟用 Storage Version Migration](https://kubernetes.io/blog/2026/08/31/kubernetes-v1-37-storage-version-migration-ga/)。

---
[內容](README_TW.md)
