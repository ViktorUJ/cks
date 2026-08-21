[Русская версия](RUNBOOK_RU.md) · [Eng version](RUNBOOK.md) · [Versión en español](RUNBOOK_ES.md) · [Version française](RUNBOOK_FR.md) · [Deutsche Version](RUNBOOK_DE.md) · [ქართული ვერსია](RUNBOOK_GE.md) · [日本語版](RUNBOOK_JP.md)

# EKS 診斷指南：症狀、原因、檢查

[課程目錄](README_TW.md) · [詞彙表](GLOSSARY_TW.md)

## 使用方式

這是第 45、46 與 47 章「診斷流程與工具」部分的摘要，彙整為單一值班檔案：發生
事件時翻閱三個章節並不方便。
使用方式如下：先依「依症狀快速切入」表格辨識症狀的**類別**，再進入對應層次並由上而下
排查。分類比工具更重要：處於 `ContainerCreating` 的 Pod 與負載平衡器回傳的 503，需以不同指令處理。
此處僅提供排查順序、檢查清單與指令。原因分析、運作機制與說明保留在第 45 至 47 章，
導覽表每一列都有對應連結。

## 依症狀快速切入

| 可見現象 | 類別 | 前往位置 |
|---|---|---|
| `kubectl get nodes` 為空，沒有節點 | 節點未加入 | [節點](#節點未加入叢集), [第 45 章](45/tw.md) |
| `NodeCreationFailure`, `Instances failed to join the kubernetes cluster` | 節點未加入 | [節點](#節點未加入叢集), [第 45 章](45/tw.md) |
| node group 為 `CREATE_FAILED` 或 `DEGRADED` | 節點未加入 | [節點](#節點未加入叢集), [第 45 章](45/tw.md) |
| kubelet 日誌出現 `node "" not found` | 節點：DNS 與 private DNS name | [節點](#節點未加入叢集), [第 45 章](45/tw.md) |
| 可見節點但為 `NotReady` | CNI 尚未就緒，屬於其他層次 | [節點](#節點未加入叢集), [第 45 章](45/tw.md), 第 8 章 |
| Pod 處於 `ContainerCreating`，`failed to assign an IP address to container` | 網路：IP 與 ENI | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| Pod 對 Pod 或 Pod 對 RDS 出現 `connection timed out`，DNS 可解析 | 網路：security group | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| 請求已送出，但連線卡住 | 網路：NACL 與 ephemeral ports | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| Pod 無法解析名稱且未通過 readiness | 網路：Pod 自有的 SG | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| DNS 時好時壞、間歇性逾時 | 網路：DNS | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| 對外部名稱產生多餘 DNS 負載 | 網路：`ndots:5` 效應 | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| target group 中的目標為 `unhealthy`，502 `Bad gateway` | 網路：負載平衡器 | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| LB 後方服務回傳 503 `Service unavailable` | 網路：沒有健康目標 | [網路](#運作中叢集的網路故障), [第 46 章](46/tw.md) |
| `You must be logged in to the server (Unauthorized)` | 存取：驗證 | [存取](#存取遭拒人員與-pod), [第 47 章](47/tw.md) |
| `couldn't get current server API group list: Unauthorized` | 存取：kubeconfig 或區域 | [存取](#存取遭拒人員與-pod), [第 47 章](47/tw.md) |
| `Forbidden: cannot <verb> resource` | 存取：RBAC | [存取](#存取遭拒人員與-pod), [第 47 章](47/tw.md) |
| Pod 呼叫 AWS 時因 `AccessDenied` 失敗 | Pod 存取：STS 與角色 | [存取](#存取遭拒人員與-pod), [第 47 章](47/tw.md) |
| Pod 因 `WebIdentityErr: failed to retrieve credentials` 失敗 | Pod 存取：IRSA | [存取](#存取遭拒人員與-pod), [第 47 章](47/tw.md) |

## 節點未加入叢集

第 45 章。症狀只有一個：`kubectl get nodes` 為空以及 `NodeCreationFailure`，但原因可能位於
不同層次。由上而下的排查順序如下：

1. IAM 層：node instance role 的權限，以及叢集中對該角色的授權（45.2 節）。
2. 網路層：通往 API server endpoint 的 443 路徑、endpoint 類型與 DNS（45.3 節）。
3. user data 與 bootstrap 層：AL2 的 `bootstrap.sh`、AL2023 的 `nodeadm`/`NodeConfig`（45.4 節）。
4. kubelet 層：常駐程式已啟動、kubeconfig 與憑證完好且註冊已完成（45.5 節）。

邏輯是：先以 `describe-nodegroup` 詢問 EKS，然後檢查角色授權
（成本低，而且最常是它造成問題），接著檢查通往 endpoint 的網路，最後才登入節點查看
cloud-init 與 kubelet 日誌。請區分「沒有節點」與 `NotReady`：後者在 kubelet 存活時幾乎
總是 CNI 問題，請見第 8 章。

| 症狀 | 可能原因 | 檢查項目 |
|---|---|---|
| `NodeCreationFailure`，沒有節點 | 節點角色未獲授權 | `aws eks list-access-entries`, `aws-auth` |
| 沒有節點，IAM 正常 | 沒有通往 API 的 443 路徑 | SG、NAT/IGW 路由、endpoint 類型 |
| 沒有節點，私有叢集 | endpoint 無法解析 | DNS、VPC 中的 DHCP options set |
| 沒有節點，自訂 AMI | bootstrap 未執行 | `/var/log/cloud-init-output.log` |
| 沒有節點，kubelet 當掉 | kubeconfig/憑證損毀 | `journalctl -u kubelet` |
| 有節點但為 `NotReady` | CNI 未就緒，Pod 沒有 IP | `aws-node` Pod、節點事件（第 8 章） |
| 日誌中有 `node "" not found` | 沒有 private DNS name | DHCP options、VPC 中的 DNS |

```bash
# 1. EKS 對 node group 的說明
aws eks describe-nodegroup --cluster-name prod --nodegroup-name ng-1 \
  --query 'nodegroup.health.issues'
# 2. 叢集是否看得到節點
kubectl get nodes
# 3. 節點角色是否已獲授權
aws eks list-access-entries --cluster-name prod
# 舊式做法：aws-auth 中的映射
kubectl -n kube-system get configmap aws-auth -o yaml
# 4. 在節點上透過 SSM Session Manager：bootstrap/cloud-init 日誌
sudo cat /var/log/cloud-init-output.log
# 5. 在節點上：kubelet 狀態與日誌
systemctl status kubelet
journalctl -u kubelet -n 200 --no-pager
```

不使用 SSH 時，透過 SSM Session Manager 存取節點：需要 SSM agent 與權限。若 SSM
無法使用，僅剩執行個體的主控台輸出（system log）與 `/var/log`。

## 運作中叢集的網路故障

第 46 章。叢集正在運作、節點為 `Ready`，但網路可能以不同方式失效。先分類
症狀：沒有 IP、連線中斷、DNS，或負載平衡器的 5xx。類別決定對應層次與指令。
`describe pod` 與 `get pods -o wide` 成本低，可最先排除 IP 問題；
`describe-target-health` 能立即定位負載平衡器故障；VPC Flow Logs 則是最後防線，用於既非 IP
也非 health check 所能解釋的中斷。請記住各層差異：security group 為 stateful，且在 ENI
層級運作；NACL 為 stateless，且在子網路層級運作，因此必須在 NACL 中手動允許回程流量的
 ephemeral ports。

| 症狀 | 可能原因 | 檢查項目 |
|---|---|---|
| `failed to assign an IP address` | 節點或子網路沒有可用 IP | `describe pod`, `AvailableIpAddressCount` |
| Pod 對 Pod 或 Pod 對 RDS timeout | SG 未允許流量 | `describe-network-interfaces` Groups、RDS SG |
| 連線中斷但請求有送出 | NACL 阻擋 ephemeral ports | NACL in/out 規則、VPC Flow Logs |
| DNS 間歇性 timeout | CoreDNS、conntrack、per-ENI throttling | CoreDNS 指標（第 33 章）、conntrack、PPS |
| 對外部名稱產生多餘 DNS 負載 | `ndots:5` 效應 | search domains、帶結尾點的 FQDN |
| LB 後方服務回傳 502 或 503 | 目標為 `unhealthy` | `describe-target-health`、health check、SG |
| 目標為 `unhealthy`，Pod 仍存活 | health check 路徑/連接埠或 SG | 檢查路徑與連接埠、負載平衡器 SG |
| Pod 沒有 DNS 且未通過 readiness | Pod 使用自有 SG 而非節點 SG | Pod 的 `SecurityGroupPolicy`、53 TCP/UDP、來自節點 SG 的入站 |

```bash
# 1. Pod 事件：ContainerCreating 與 IP 配發的原因
kubectl describe pod <pod>
# 2. Pod 位於何處及在哪個節點
kubectl get pods -o wide
# 3. 特定 IP 的 ENI、IP 與 SG
aws ec2 describe-network-interfaces \
  --filters "Name=private-ip-address,Values=<ip>" --query 'NetworkInterfaces[0]'
# 4. 子網路中的可用位址
aws ec2 describe-subnets --subnet-ids <subnet> \
  --query 'Subnets[0].AvailableIpAddressCount'
# 5. 負載平衡器目標健康狀態
aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
# 服務後方是否有 ready endpoints
kubectl get endpointslices -l kubernetes.io/service-name=<svc>
# 6. 從 Pod 檢查名稱解析
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup <name>
# Pod 自有 SG：套用模式及尋找 SG ID 錯誤
kubectl describe daemonset aws-node -n kube-system | grep -iE 'SECURITY_GROUP|DEMUX'
kubectl describe pod <pod> | grep -i InvalidSecurityGroupID
# 7. 在節點上：收集 VPC CNI 網路傾印（ipamd/plugin 日誌、ENI、eni-configs）
aws ssm send-command --document-name "AWS-RunShellScript" --instance-ids <instance-id> \
  --parameters 'commands=["/opt/cni/bin/aws-cni-support.sh"]'
```

ipamd 的狀態亦可直接透過其本機 endpoint 檢視：`/v1/enis` 顯示已配發的 ENI 與 IP，
`/v1/pods` 顯示位址與 Pod 的繫結。

## 存取遭拒：人員與 Pod

第 47 章。存取故障分為兩個彼此獨立的軸線，值班人員的第一個問題是：哪一個壞了？
人員或 CI 無法登入叢集，或是 Pod 呼叫 AWS 時得到 `AccessDenied`。
接著以拒絕碼完成分類。`Unauthorized` (401) 代表驗證失敗：沒有 token、token 已過期，或 identity
未被映射；在 kubeconfig、credentials 與映射（access entry 或 aws-auth）中修正。
`Forbidden` (403) 代表授權失敗：identity 已被識別，但 RBAC 未授予權限；在 Role、ClusterRole
與 bindings 中修正。Pod 回傳的 `AccessDenied` 則指向 IRSA 或 Pod Identity。可快速判斷「叢集還是我」：
若 `aws sts get-caller-identity` 顯示錯誤的 identity，問題在本機：profile、區域或 credentials。

| 症狀 | 可能原因 | 檢查項目 |
|---|---|---|
| `Unauthorized`, `must be logged in` | identity 錯誤或未映射 | `sts get-caller-identity`, `list-access-entries` |
| `edit aws-auth` 後立即 `Unauthorized` | 自己的映射遭刪除 | `get cm aws-auth`，透過 access entry 還原 |
| `Forbidden: cannot <verb>` | RBAC 未授予權限 | `kubectl auth can-i`、Role 與 bindings |
| `couldn't get server API group` | kubeconfig 或區域損毀 | `update-kubeconfig`, `current-context`, profile |
| 使用 IRSA 的 Pod 出現 `AccessDenied` | trust policy、OIDC、SA annotation | OIDC provider、`sub`/`aud`、`role-arn` annotation |
| Pod 出現 `WebIdentityErr` | token 未掛載，或角色錯誤 | 重新建立 Pod、檢查 trust policy |
| 使用 Pod Identity 的 Pod 出現 `AccessDenied` | 沒有 association、agent 或 token | `list-pod-identity-associations`、agent、Pod 中的 token |

```bash
# 在 AWS 眼中我實際是誰
aws sts get-caller-identity
# 叢集的驗證模式與 accessConfig
aws eks describe-cluster --name <cluster> --query 'cluster.accessConfig'
# 經由 access entries 映射的對象
aws eks list-access-entries --cluster-name <cluster>
# aws-auth 的內容（若模式仍使用它）
kubectl -n kube-system get cm aws-auth -o yaml
# authz：我實際可做什麼
kubectl auth can-i --list
kubectl auth can-i get pods -n <ns>
# 重新產生 kubeconfig 並檢查 context
aws eks update-kubeconfig --name <cluster> --region <region> --profile <profile>
kubectl config current-context
# Pod 軸線：ServiceAccount 上的角色 annotation（IRSA）
kubectl get sa <sa> -n <ns> -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
# Pod Identity associations
aws eks list-pod-identity-associations --cluster-name <cluster>
# Pod Identity agent 是否已啟動
kubectl -n kube-system get pods -l app.kubernetes.io/name=eks-pod-identity-agent
# Pod Identity token 是否已掛載在 Pod 本身中（沒有檔案表示 agent/association 未生效）
kubectl exec <pod> -n <ns> -- ls /var/run/secrets/pods.eks.amazonaws.com/serviceaccount/
```

遭鎖定的叢集可透過 EKS API 還原：以 `authenticationMode=API_AND_CONFIG_MAP` 執行
`update-cluster-config`，接著執行 `create-access-entry` 與
`associate-access-policy` 並使用 `AmazonEKSClusterAdminPolicy`（47.4 節）。無法再切換回
`CONFIG_MAP`。

## 當一切都對不上時該看什麼

- **VPC Flow Logs** 記錄封包在 ENI 或子網路層級收到 `ACCEPT` 還是 `REJECT`。
  `REJECT` 指向 SG 或 NACL；若請求已送出卻沒有回應封包，則指向 stateless NACL 與
  ephemeral ports。
- **control plane 日誌**（api、audit、authenticator）應事先啟用，而非事後才開：
  authenticator 日誌顯示傳入的 identity 是否已映射（第 21 與 34 章）。
- **透過 SSM 的 `aws-cni-support.sh`** 會將 ipamd 與 plugin 日誌，以及 ENI/IP 狀態和
  設定收集至 `/var/log/eks_<instance-id>_<...>.tar.gz` 封存檔，無須 SSH 登入節點。
- **`/var/log/aws-routed-eni` 日誌**（`ipamd.log`、`plugin.log`）應在節點上讀取，當 Pod 卡在
  `failed to assign an IP address`，且不確定是 IP 耗盡還是 ENI 未建立時。

## 此處未涵蓋的內容

此文件不是各章的替代品：此處沒有原因說明、層次運作機制，也未分析為何症狀會以特定方式
呈現，這些內容位於第 45、46 與 47 章。此處只有排查順序與指令。
課程的 troubleshooting labs（119、120、121，以及關於 security groups for pods 的 126）不在此檔案中
重複：請依各自的作業完成。