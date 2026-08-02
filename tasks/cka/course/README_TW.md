[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [日本語版](README_JP.md)

# CKA + CKAD:Kubernetes 實作自學教材

同時準備 CNCF 與 Linux Foundation 兩張證照的聯合實作課程:

- **CKA**(Certified Kubernetes Administrator) - 叢集的管理:
  安裝、維運、網路、儲存、安全性、troubleshooting。
- **CKAD**(Certified Kubernetes Application Developer) - 在 Kubernetes 中
  開發與執行應用程式:工作負載、設定、可觀測性、
  服務。

兩場考試的重疊很大(工作負載、服務、設定、儲存、
可觀測性),因此一起學比分開學更有效率。共同的
核心只走一次,而每場考試的專屬內容則各自放在獨立的部分。
本課程與 `tasks/cka/labs` 中的實驗綁在一起。

> **Kubernetes 版本。** 本課程對準考試的現行版本 -
> Kubernetes `v1.35`(CKA 與 CKAD 2025-2026 大綱)。兩場考試都是
> 實作型,在真實叢集中用命令列完成:CKA - 2 小時,CKAD - 2
> 小時,及格分數 66%。

## 課程的結構

每個主題都是一個帶編號的資料夾。裡面放著各語言的檔案。主要語言是
俄文(`ru.md`),其他都是從它翻譯而來:英文(`README.md`)、西班牙文
(`es.md`)、法文(`fr.md`)、德文(`de.md`)與喬治亞文(`ge.md`)。
語言切換器就在每個檔案的第一行。

每一章都標示了它屬於哪一場考試:

- 🟦 **CKA** - 只給管理員
- 🟩 **CKAD** - 只給開發者
- 🟪 **CKA + CKAD** - 兩場考試共通的主題

課程最後有兩份獨立的導覽,把章節與實驗依照
特定考試整理起來:

- [CKA 的大綱與實驗](CKA_TW.md)
- [CKAD 的大綱與實驗](CKAD_TW.md)

課程的所有術語都收在同一份參考資料中:

- [課程詞彙表](GLOSSARY_TW.md) - 依章節整理的所有術語,附連結

## 考試的官方大綱

CKA(領域與權重):

| 領域 | 權重 |
|-------|-----|
| Cluster Architecture, Installation & Configuration | 25% |
| Workloads & Scheduling | 15% |
| Storage | 10% |
| Services & Networking | 20% |
| Troubleshooting | 30% |

CKAD(領域與權重):

| 領域 | 權重 |
|-------|-----|
| Application Design and Build | 20% |
| Application Deployment | 20% |
| Application Observability and Maintenance | 15% |
| Application Environment, Configuration and Security | 25% |
| Services and Networking | 20% |

## 目錄

### 第 0 部分。給新手的地基(非必要)🟪 CKA + CKAD

這是為那些在網路、DNS、TLS、容器、Linux 與 YAML 上沒有紮實基礎就
進來的人準備的預備部分。如果你對這些主題很有把握 - 可以直接
跳到第 1 部分。這一部分沒有自己的實驗:它是其餘章節所依靠的
地基(0.5-0.7 的技能會直接用在節點與網路的
實驗裡)。

- 0.1. [從零開始學網路:IP、埠、CIDR 與 NAT](00-1-net/tw.md)
- 0.2. [DNS 從零開始:名稱如何變成位址](00-2-dns/tw.md)
- 0.3. [從零開始理解 TLS 與憑證:HTTPS、金鑰與憑證授權中心](00-3-tls/tw.md)
- 0.4. [從零開始的容器與 Docker:映像、層、registry 與 runtime](00-4-containers/tw.md)
- 0.5. [從零開始的 Linux 與節點工具:SSH、sudo、systemd、日誌、檔案](00-5-linux/tw.md)
- 0.6. [從零開始的 YAML:縮排、清單、字典與 manifest](00-6-yaml/tw.md)
- 0.7. [Linux 網路的底層原理:network namespace、veth 與路由](00-7-netns/tw.md)
- 0.8. [15 分鐘學會 vim:先活下來,再調成適合 YAML](00-8-vim/tw.md)

### 第 1 部分。Kubernetes 基礎 🟪 CKA + CKAD

1. [導論:Kubernetes、CKA 與 CKAD 考試,以及本課程的結構](01/tw.md)
2. [Kubernetes 架構:control plane 與 worker 節點](02/tw.md)
3. [使用 kubectl:命令式與宣告式兩種做法](03/tw.md)
4. [Pod:生命週期、建立與設定](04/tw.md)
5. [ReplicaSet 與 Deployment](05/tw.md)
6. [Namespaces、labels、selectors 與 annotations](06/tw.md)
7. [Services:ClusterIP、NodePort、LoadBalancer、Endpoints](07/tw.md)

### 第 2 部分。工作負載與排程 🟪 CKA + CKAD

8. [Deployment:rolling update 與 rollback](08/tw.md)
9. [部署策略:blue/green 與 canary](09/tw.md) 🟩 CKAD
10. [Jobs 與 CronJobs](10/tw.md)
11. [DaemonSet 與 StatefulSet](11/tw.md)
12. [Pod 的排程:nodeName、nodeSelector、affinity](12/tw.md)
13. [Taints 與 tolerations](13/tw.md)
14. [資源:requests、limits、LimitRange、ResourceQuota](14/tw.md)
15. [Static Pods、PriorityClass、多個排程器](15/tw.md)
16. [工作負載的自動擴縮:HPA](16/tw.md)

### 第 3 部分。應用程式的設定與安全性 🟪 CKA + CKAD

17. [指令、參數與環境變數](17/tw.md)
18. [ConfigMap](18/tw.md)
19. [Secret](19/tw.md)
20. [SecurityContext 與 capabilities](20/tw.md)
21. [ServiceAccount;認證、授權與 admission](21/tw.md)

### 第 4 部分。應用程式的設計與建置 🟩 CKAD

22. [Multi-container Pod:sidecar、adapter、ambassador、init](22/tw.md)
23. [容器映像:建置、Dockerfile、最佳化](23/tw.md)
24. [給應用程式用的卷:emptyDir 與臨時卷](24/tw.md)

### 第 5 部分。資料的儲存 🟪 CKA + CKAD

25. [Volumes、PersistentVolume 與 PersistentVolumeClaim](25/tw.md)
26. [StorageClass、動態佈建、StatefulSet 中的儲存](26/tw.md)

### 第 6 部分。可觀測性與維運 🟪 CKA + CKAD

27. [健康檢查:liveness、readiness、startup 探測](27/tw.md)
28. [日誌與監控:logs、metrics-server、kubectl top](28/tw.md)
29. [應用程式除錯與 API 淘汰](29/tw.md)

### 第 7 部分。服務與網路 🟪 CKA + CKAD

30. [Kubernetes 網路模型、Pod 網路與 CNI](30/tw.md)
31. [Service 的內部運作、DNS 與 CoreDNS](31/tw.md)
32. [Ingress 與 Ingress 控制器](32/tw.md)
33. [Gateway API](33/tw.md)
34. [NetworkPolicy](34/tw.md)

### 第 8 部分。叢集架構、安裝與設定 🟦 CKA

35. [使用 kubeadm 安裝叢集](35/tw.md)
- 35A. [高可用性(HA):多個 control-plane 節點、etcd 拓撲與負載平衡器](35-2-ha/tw.md) 🟦 CKA
- 35B. [叢集的設計與容量規劃:基礎設施、拓撲、IaC](35-3-design/tw.md) 🟦 CKA
36. [叢集升級(lifecycle)](36/tw.md)
37. [etcd 的備份與還原](37/tw.md)
38. [RBAC:Role、ClusterRole 與 binding](38/tw.md)
39. [TLS 憑證、kubeconfig 與 CSR API](39/tw.md)
40. [擴充介面:CNI、CSI、CRI](40/tw.md)
41. [CRD 與 operator](41/tw.md)
42. [Helm](42/tw.md)
43. [Kustomize](43/tw.md)

### 第 9 部分。Troubleshooting 🟦 CKA

44. [應用程式故障除錯](44/tw.md)
45. [control plane 與 worker 節點的除錯](45/tw.md)
46. [服務與網路的除錯](46/tw.md)

### 第 10 部分。考試準備

47. [CKAD 考試:形式、時間管理、JSONPath 與 kubectl 生產力](47/tw.md) 🟩 CKAD
48. [CKA 考試:形式、時間管理與策略](48/tw.md) 🟦 CKA

## 實踐

- 🧪 [實驗](../labs) - 25 個考試風格的實驗,附自動檢查 `check_result`
- 🧪 [CKA 模擬考](../mock) - 計時的 CKA 模擬考(多叢集、SSH、題目權重)
- 🧪 [CKAD 模擬考](../../ckad/mock) - 計時的 CKAD 模擬考

### 該選哪一種實驗

我們平台的實驗是本課程的主要練習,也更適合用來準備考試:它們是複合式的(同一個環境裡
有多個彼此相關的題目,就像真正的考試),部署在完整的叢集上、可以用 SSH 進到節點,並且
由 `check_result` 自動驗證,而模擬考則是計時進行、題目帶權重。正是這些重現了 CKA 與
CKAD 的考試條件。

各章中的 Killercoda 情境是**快速上手**用的:在瀏覽器裡打開、不需安裝、而且免費。讀完
一章之後馬上做一個,用來鞏固某個單一主題很方便;手邊沒有叢集時也可以拿來練習。但它們
是原子式的(一個情境一個題目)、只有英文,而且既不能在節點上操作,也沒有計時的演練。

建議的搭配方式:Killercoda 用來快速鞏固單一主題,我們的實驗與模擬考用來準備考試本身。

## 接下來讀什麼

本課程聚焦在考試準備上:每一章都對應到 CKA 或 CKAD 的某個領域。架構哲學、專案的歷史,
以及生態系的概覽(service mesh、GitOps、可觀測性)刻意沒有放進來 - 那些是獨立的主題,
考試不會問。如果你想看得更廣、更深:

- **Kubernetes: Up and Running**(Burns、Beda、Hightower,O'Reilly) - Kubernetes 為何
  出現、從 Borg 的演進、應用程式的架構模式。
- **The Kubernetes Book**(Nigel Poulton) - 概覽式的入門,重點在於整體理解這個平台;
  每年更新。
- [Kubernetes 官方文件](https://kubernetes.io/docs/) - 第一手來源,考試當下也允許查閱。
- [CNCF Landscape](https://landscape.cncf.io/) - cloud native 生態系的地圖。
