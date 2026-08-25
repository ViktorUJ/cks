[Русская версия](README_RU.md) · [Eng version](README.md) · [Versión en español](README_ES.md) · [Version française](README_FR.md) · [Deutsche Version](README_DE.md) · [ქართული ვერსია](README_GE.md) · [日本語版](README_JP.md)

# Amazon EKS：正式環境維運實作自學教材

與 `tasks/eks/labs` 中實驗綁定的 Amazon EKS 實作課程。課程適合**已通過 CKA**（或具備 Kubernetes 管理員程度的扎實能力），正要轉向在 AWS 管理受管叢集的工程師。

EKS 並無獨立認證，因此本課程並非為考試而設計，而是聚焦真實維運：當 AWS 維護 control plane，而節點、網路、存取權限、成本與升級仍由您負責時，工程師需要承擔的工作。

> **預設已具備的知識。** Pod、Deployment、Service、Ingress、RBAC、PV/PVC、probes、kubectl 與工作負載除錯，皆為 CKA 課程的基礎，這裡不再重複。若尚未掌握這些主題，請先從 [CKA + CKAD 課程](../../cka/course/README_TW.md) 開始。

> **版本。** 課程以目前 EKS 版本（Kubernetes `1.33` 至 `1.36`）為準。EKS 有自己的版本生命週期：14 個月 standard support 加上 12 個月 extended support（每個 minor 版本共 26 個月），因此升級章節著重於流程，而非特定版本號。課程實驗會使用各實驗 `env.hcl` 中指定的版本部署。

## 課程結構

每個主題皆為帶有編號的資料夾，內含本地化檔案。主要語言為俄文（`ru.md`），其餘語言將由此翻譯而來（與 CKA 及 Istio 課程相同）。首次翻譯後，語言切換器會出現在每個檔案的第一行。

課程需要**自己的 AWS 帳戶**：幾乎所有主題都只能在實際叢集上驗證，有些情境（spot 中斷、NAT 與流量、升級、成本）無法在本機 kind 中重現。實驗透過 Terragrunt 部署，並可用一條指令刪除，以免持續產生費用。

除章節與實驗外，課程還有實用參考資料，不必依序閱讀，而是按需查閱：

- [課程詞彙表](GLOSSARY_TW.md) - 依章節分類並附連結的所有術語
- [診斷參考指南](RUNBOOK_TW.md) - 症狀、原因、檢查方式：彙整第 8 部分內容
- [架構決策（ADR）](ADR_TW.md) - 針對課程中各種分支選擇的決策範本
- [EKS 成熟度矩陣](SCORECARD_TW.md) - 依八個領域評估叢集準備度的問卷
- [成本模型](COST_MODEL_TW.md) - 成本項目與公式清單，請代入您自己的費率

## 目錄

### 第 0 部分：AWS 基礎（選修）

提供給 Kubernetes 能力強、AWS 基礎較弱的學習者。若 IAM、VPC 與 EC2 已是熟悉工具，請直接前往第 1 部分。本部分沒有獨立實驗；其目的在於讓您閱讀後續章節時不留知識缺口。

- 0.1. [Kubernetes 工程師的 AWS：帳戶、區域、AZ、配額、標籤、計費](00-1-aws/tw.md)
- 0.2. [從零開始學 IAM：policy、role、信任關係、STS 與暫時金鑰](00-2-iam/tw.md)
- 0.3. [從零開始學 VPC：子網路、路由、IGW 與 NAT、security group、VPC endpoint](00-3-vpc/tw.md)
- 0.4. [EC2 與計費模式：執行個體類型、AMI、on-demand、spot、Savings Plans](00-4-ec2/tw.md)
- 0.5. [工具：aws cli、eksctl、terraform 與 terragrunt、helm、實用外掛](00-5-tools/tw.md)

### 第 1 部分：叢集架構與建立

1. [簡介：EKS 負責什麼，以及哪些仍由您負責](01/tw.md)
2. [EKS control plane：public 與 private endpoint、platform versions、SLA、日誌](02/tw.md)
3. [版本生命週期：standard 與 extended support、升級策略](03/tw.md)
4. [建立叢集：eksctl、Terraform 與 Terragrunt、CloudFormation](04/tw.md) 🧪
5. [叢集存取：IAM 與 RBAC、access entries、從 aws-auth 遷移](05/tw.md)
6. [叢集網路：VPC CNI、ENI 與 IP 位址、CIDR 規劃](06/tw.md) 🧪
7. [位址規劃的擴充：prefix delegation、secondary CIDR、custom networking](07/tw.md)
8. [VPC CNI 的替代方案：Cilium、網路模式、何時更換 CNI](08/tw.md) 🧪

### 第 2 部分：節點與運算資源

9. [運算類型：managed node groups、self-managed、Fargate、Auto Mode](09/tw.md) 🧪
10. [AMI 與 bootstrap：AL2023、Bottlerocket、launch templates、kubelet 與 user data](10/tw.md) 🧪
11. [Cluster Autoscaler 與 Karpenter：兩種節點擴展方法](11/tw.md)
12. [Karpenter：NodePool、EC2NodeClass、disruption、consolidation、drift](12/tw.md)
13. [Spot 執行個體：中斷、多樣化、事件處理](13/tw.md)
14. [密度與 sizing：pods per node、ENI 限制、雲端中的 requests 與 limits](14/tw.md)
15. [Fargate：profile、限制、成本、使用情境](15/tw.md)

### 第 3 部分：身分與安全性

16. [IRSA：OIDC provider、trust policy、ServiceAccount 註解](16/tw.md)
17. [EKS Pod Identity：agent、association、從 IRSA 遷移](17/tw.md)
18. [Secrets：KMS 加密、透過 External Secrets 與 CSI 使用 Secrets Manager 和 SSM](18/tw.md)
19. [強化：IMDSv2 與 hop limit、Pod Security Admission、private cluster](19/tw.md)
20. [映像與 supply chain：ECR、掃描、簽章、pull through cache](20/tw.md) 🧪
21. [稽核與偵測：control plane 日誌、CloudTrail、GuardDuty、runtime monitoring](21/tw.md)
22. [Policy 與多租戶：Kyverno 與 Gatekeeper、團隊隔離](22/tw.md) 🧪

### 第 4 部分：資料儲存

23. [EBS CSI：gp3、StorageClass、擴容、snapshot、AZ 綁定](23/tw.md)
24. [EFS 與 FSx：跨 AZ 工作負載的 shared storage](24/tw.md)
25. [應用程式中的 S3：Mountpoint for Amazon S3 CSI 與存取模式](25/tw.md) 🧪

### 第 5 部分：網路與流量

26. [AWS Load Balancer Controller 與 LoadBalancer 類型的 Service：NLB](26/tw.md)
27. [透過 ALB 使用 Ingress：target-type、註解、TLS 與 ACM、WAF](27/tw.md)
28. [AWS 中的 Gateway API：ALB Gateway API 與 VPC Lattice](28/tw.md) 🧪
29. [DNS 與憑證：external-dns、Route 53、cert-manager](29/tw.md)
30. [EKS 中的 NetworkPolicy：VPC CNI network policy 與 Cilium](30/tw.md)
31. [Egress 與流量成本：NAT、VPC endpoints、PrivateLink](31/tw.md)
32. [多叢集與多帳戶：連通性、共用資源、模式](32/tw.md)

### 第 6 部分：可觀測性

33. [指標：Container Insights、Managed Prometheus 與 Grafana、kube-prometheus-stack](33/tw.md)
34. [日誌：Fluent Bit、CloudWatch Logs、OpenSearch、成本控管](34/tw.md)
35. [應用程式自動擴展：HPA、外部指標、KEDA](35/tw.md) 🧪
36. [追蹤與效能分析：ADOT 與 X-Ray](36/tw.md)

### 第 7 部分：維運

37. [EKS add-on：managed addons 與 Helm 的比較、版本與升級順序](37/tw.md)
38. [叢集升級：按版本 in-place 升級、blue/green 叢集、已淘汰的 API](38/tw.md)
39. [叢集版本回復：rollback readiness insights、7 天視窗、回復順序](39/tw.md)
40. [可靠性：multi-AZ、PDB、topology spread、正確關閉節點](40/tw.md) 🧪
41. [透過 AWS Backup 備份叢集：叢集狀態、persistent volumes、composite recovery point](41/tw.md) 🧪
42. [復原與 DR：還原至既有或新叢集、namespace restore、Velero](42/tw.md) 🧪
43. [成本：OpenCost 與 Kubecost、right-sizing、Savings Plans、spot 組合、流量](43/tw.md)
44. [GitOps 與交付：Argo CD 與 Flux、叢集艦隊管理](44/tw.md) 🧪

本部分配有兩份參考資料：[成本模型](COST_MODEL_TW.md) - 第 43 章的估算表單，以及[架構決策](ADR_TW.md) - 涵蓋全課程各項分支選擇的 ADR 範本。

### 第 8 部分：疑難排解

45. [節點未加入叢集：IAM、SG、user data、bootstrap、kubelet](45/tw.md)
46. [網路故障：ENI exhausted、SG 與 NACL、DNS、負載平衡器中的 unhealthy targets](46/tw.md) 🧪
47. [存取與 IAM：access entries、IRSA 與 Pod Identity、webhook、kubeconfig](47/tw.md) 🧪

這三章的「診斷順序」部分彙整於[診斷參考指南](RUNBOOK_TW.md)：症狀、可能原因與待檢查項目。值班時開啟它比查閱三個章節更方便。

### 第 9 部分：總結

48. [EKS 正式環境檢查清單與後續閱讀](48/tw.md)

第 48 章的檢查清單已整理為附有分數與技術債清單的問卷：[EKS 成熟度矩陣](SCORECARD_TW.md)。

## 實作

課程有一套自己的實驗，編號為 `101+`，並與章節相連。實驗會透過 Terragrunt 在您的 AWS 帳戶中部署，由 `check_result` 自動檢查，並可用一條指令刪除：

- 🧪 [EKS 實驗](../../../docs/labs.MD#eks-labs) - 實驗清單與啟動指令

課程實驗套件目前仍在建置中。目錄中的 🧪 標記表示該章節已有實驗；未標記的章節目前僅能作為理論學習。

儲存庫另有較早期的 EKS 實驗（[Karpenter](../labs/02/README_TW.MD)、[使用 KEDA 與 Prometheus 的自動擴展](../labs/03/README_TW.MD)）。它們不屬於本課程且獨立維護，但主題與第 12 及第 35 章重疊，因此可作為補充實作。

## 後續閱讀

- [Amazon EKS 文件](https://docs.aws.amazon.com/eks/latest/userguide/) - 版本、add-on 與限制的第一手資料。
- [EKS Best Practices Guides](https://docs.aws.amazon.com/eks/latest/best-practices/) - 關於網路、安全性、可靠性與成本的官方建議。
- [EKS Workshop](https://www.eksworkshop.com/) - AWS 提供的免費互動式模組。
- [AWS Backup：EKS 備份與復原](https://docs.aws.amazon.com/aws-backup/latest/devguide/eks-backups.html) - 關於叢集狀態與 persistent volumes 備份的文件。
- [從 Spot.io 到 Karpenter](../../../docs/articles/from_spot_io_to_karpenter/readme_RU.MD) - 我們對正式環境中節點管理遷移的解析。
