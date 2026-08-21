[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# 實驗：Karpenter 基礎

## 說明

本實驗將帶您認識 **Karpenter**——Amazon EKS 叢集中的節點自動擴縮工具。Karpenter 會依據應用程式需求動態建立與刪除 EC2 執行個體，以最佳化成本與效能。

**您將學習：**
- 如何設定基本的 NodePool 與 EC2NodeClass
- Karpenter 如何在負載變更時自動擴縮節點
- 如何透過限制管理資源
- 整併與節點大小最佳化的運作方式
- 如何在設定變更時更新節點（drift）
- 如何針對不同負載類型使用多個 NodePool

## 目錄
- [環境準備](#環境準備)
  - [啟動實驗](#啟動實驗)
  - [建立的資源](#建立的資源)
  - [先決條件](#先決條件)
- [基本 NodePool 設定](#基本-nodepool-設定)
  - [檢查 Karpenter 運作狀態](#檢查-karpenter-運作狀態)
  - [建立測試應用程式](#建立測試應用程式)
  - [建立 NodePool 與 EC2NodeClass](#建立-nodepool-與-ec2nodeclass)
  - [檢查節點自動建立](#檢查節點自動建立)
- [擴展應用程式](#擴展應用程式)
  - [水平擴展](#水平擴展)
  - [自動新增節點](#自動新增節點)
- [資源限制](#資源限制)
  - [設定 CPU 限制](#設定-cpu-限制)
  - [診斷限制問題](#診斷限制問題)
- [節點生命週期管理 (Disruption)](#節點生命週期管理-disruption)
- [節點大小最佳化 (RightSizing)](#節點大小最佳化-rightsizing)
  - [自動選擇最佳大小](#自動選擇最佳大小)
  - [需求變更時替換節點](#需求變更時替換節點)
- [節點設定更新 (Drift)](#節點設定更新-drift)
  - [更新 AMI 映像](#更新-ami-映像)
  - [自動遷移至新版本](#自動遷移至新版本)
- [使用多個 NodePool](#使用多個-nodepool)
  - [透過 Taints 與 Tolerations 隔離負載](#透過-taints-與-tolerations-隔離負載)
  - [Job 的專用節點](#job-的專用節點)
- [清理資源](#清理資源)

## 環境準備

### 啟動實驗
[透過 docker 啟動](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)
若要啟動實驗，請執行以下命令：

```bash
TASK=02 make run_eks_task
```

**執行命令時會發生什麼事：**
- Terraform/Terragrunt 會自動在 AWS 部署所有必要基礎設施
- 此程序約需 15-20 分鐘
- 您會在命令輸出中看到重要資訊（SSH 連線、資源名稱）

### 建立的資源

執行命令時，將部署下列 AWS 基礎設施：

#### 網路基礎設施 (VPC)
- 位於 `eu-central-1` 區域、CIDR 區塊為 `10.10.0.0/16` 的 **VPC**
- **公有子網路**（供可存取網際網路的資源使用）：
  - 可用區域 `eu-central-1a` 中的 `eks-AZ-1` (10.10.1.0/24)
  - 可用區域 `eu-central-1b` 中的 `eks-AZ-2` (10.10.2.0/24)
- **私有子網路**（供內部資源使用）：
  - `eu-central-1a` 中供 EKS 節點使用的 `private-subnet-1` (10.10.15.0/24)
  - `eu-central-1b` 中供 EKS 節點使用的 `private-subnet-2` (10.10.16.0/24)
  - `eu-central-1a` 中供 RDS 使用的 `rds-subnet-1` (10.10.21.0/24)
  - `eu-central-1b` 中供 RDS 使用的 `rds-subnet-2` (10.10.22.0/24)
- 用於私有子網路對外網際網路流量的 **NAT Gateway**

#### EKS 叢集
- `1.34` 版本的 **EKS Control Plane**（Kubernetes 控制平面）
- 系統 Pod 的 **Fargate profile** (kube-system, karpenter)
- `1.8.1` 版本的 **Karpenter**（自動擴縮控制器）
- **EKS Add-ons**：coredns、kube-proxy、vpc-cni、eks-pod-identity-agent

#### Karpenter 設定
- 具有專屬資源的 Karpenter 控制器：
  - CPU：0.4 個核心（requests 與 limits）
  - Memory：0.5Gi（requests 與 limits）
- 透過 `karpenter.sh/discovery` 標籤自動探索子網路

#### 其他元件
- 具備相應安全規則的 **Security Groups**
- Karpenter 與 EKS 的 **IAM 角色和政策**
- 供 AWS 服務整合使用的 **OIDC provider**

#### 主要設定檔

所有基礎設施參數皆定義於 `tasks/eks/labs/02/env.hcl` 檔案中。若要變更設定，請編輯該檔案中的相應參數。

### 先決條件

請確認您已設定：
- 具備相應存取權限的 **AWS CLI**
- `eu-central-1` 區域中增加的節點數量限制（如有需要）

## 基本 NodePool 設定

### 檢查 Karpenter 運作狀態

**步驟 1：連線至工作節點**

在命令輸出中找到 SSH 連線字串，並連線至工作節點：

```bash
# 輸出範例：
# 18:45:18.510 STDOUT [worker] terraform: worker_pc_ssh = "   ssh ubuntu@18.199.222.47 password= x2HcfbM577   "

ssh ubuntu@18.199.222.47  # 使用您的 IP 位址與密碼
```

**步驟 2：檢查 Karpenter 控制器狀態**

確認 Karpenter 控制器已啟動且正在運作：

```bash
kubectl get po -n karpenter
```

**預期結果：**
```
NAME                         READY   STATUS    RESTARTS   AGE
karpenter-846b886fb4-6fpxw   1/1     Running   0          12m
```

**步驟 3：檢查現有的 NodePool 與 EC2NodeClass**

確認目前尚未建立任何 NodePool：

```bash
kubectl get nodepools
```

**結果：**
```
No resources found
```

檢查 EC2NodeClass：

```bash
kubectl get ec2nodeclasses
```

**結果：**
```
No resources found
```

**這表示：**NodePool 與 EC2NodeClass 是 Karpenter 的核心資源。NodePool 定義要建立哪些節點，EC2NodeClass 則定義其設定方式（AMI、子網路、security groups 等）。

### 建立測試應用程式

部署一個簡易測試應用程式：

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**結果：**
```
namespace/team-19 created
deployment.apps/team19 created
service/team19 created
```

**步驟 4：檢查 Pod 狀態**

檢查建立的 Pod 狀態：

```bash
kubectl get po -n team-19
```

**結果：**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-4pqvn   0/1     Pending   0          2m6s
```

**請注意：**Pod 處於 `Pending`（等待）狀態。這在目前階段是正常的。

**步驟 5：診斷問題**

查看 Pod 的詳細資訊：

```bash
kubectl describe po -n team-19
```

**輸出的重要部分：**
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  2m56s  default-scheduler  0/3 nodes are available: 3 node(s) had untolerated taint(s). no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.
```

**問題說明：**
- Pod 無法被排程到任何節點
- 現有的全部 3 個節點都是供系統 Pod 使用的 Fargate 節點 (kube-system, karpenter)
- Fargate profile 僅針對特定 namespace 設定，而 `team-19` 不在其中
- 我們必須建立 NodePool，讓 Karpenter 可以建立適當的 EC2 節點

### 建立 NodePool 與 EC2NodeClass

**步驟 6：建立 NodePool**

NodePool 定義 Karpenter 將建立的節點參數：

```bash
cat <<EoF> default-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    metadata:
      labels:
        work_type: "default_karpenter"  # 用於識別節點的標籤
    spec:
      requirements:
        # 支援的處理器架構
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        # 作業系統
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        # 執行個體類型：spot（較便宜）或 on-demand（較穩定）
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        # 執行個體系列（t - burstable、m - general purpose、r - memory optimized）
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        # 執行個體世代（大於 2 = 較新）
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        # 執行個體大小
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      # 對具 AWS 設定之 EC2NodeClass 的參照
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      # 節點生命週期（30 天）
      expireAfter: 720h # 30 * 24h = 720h
  # 整個 NodePool 的資源限制
  limits:
    cpu: 4  # 此 pool 中所有節點最多 4 CPU
  # 整併（最佳化）設定
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized  # 刪除空白或使用率不足的節點
    consolidateAfter: 30s  # 節點變空白後 30 秒
EoF

kubectl apply -f default-nodepool.yaml
```

**步驟 7：從 Terraform 輸出取得參數**

在 `make run_eks_task` 命令輸出中找到以下值：

```bash
# 輸出範例：
# 19:53:19.507 STDOUT [worker] terraform: eks_name = "eks2-viktor-01"
# 20:26:31.128 STDOUT [worker] terraform: karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**步驟 8：建立 EC2NodeClass**

EC2NodeClass 定義節點的 AWS 特定設定：

```bash
cat <<EoF> default-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # 節點的 IAM 角色（替換為 Terraform 輸出中的值）
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"
  # 選擇 AMI 映像
  amiSelectorTerms:
    - alias: "al2023@latest"  # Amazon Linux 2023，最新版本
  # 依標籤選擇子網路
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 替換為您的叢集名稱
  # 依標籤選擇 security groups
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 替換為您的叢集名稱
  # 為建立的 EC2 執行個體設定標籤
  tags:
      Name: "eks2-viktor-01-default"  # 替換為您的叢集名稱
      team: "infra"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01  # 替換為您的叢集名稱
  # 磁碟設定
  blockDeviceMappings:
    - deviceName: /dev/xvda    # 根磁碟
      ebs:
        volumeType: gp3        # 磁碟類型（gp3 - 現代、高效能）
        volumeSize: 25Gi       # 磁碟大小
        iops: 3000             # gp3 的 IOPS
        throughput: 125        # MiB/s 吞吐量
        encrypted: true        # 磁碟加密
        deleteOnTermination: true  # 終止執行個體時刪除磁碟
EoF

kubectl create -f default-nodeclass.yaml
```

### 檢查節點自動建立

**步驟 9：檢查資源狀態**

確認 EC2NodeClass 已建立且就緒：

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**預期結果：**
```
NAME      READY   AGE
default   True    2m17s
```

檢查 NodePool：

```bash
kubectl get nodepools.karpenter.sh
```

**預期結果：**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     1       True    55m
```

**若狀態不是 READY：**

診斷 EC2NodeClass：

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws default
```

**成功輸出範例：**
```
Events:
  Type    Reason                     Age    From       Message
  ----    ------                     ----   ----       -------
  Normal  AMIsReady                  5m44s  karpenter  Status condition transitioned, Type: AMIsReady, Status: Unknown -> True
  Normal  CapacityReservationsReady  5m44s  karpenter  Status condition transitioned, Type: CapacityReservationsReady, Status: Unknown -> True
  Normal  SubnetsReady               5m44s  karpenter  Status condition transitioned, Type: SubnetsReady, Status: Unknown -> True
  Normal  SecurityGroupsReady        5m44s  karpenter  Status condition transitioned, Type: SecurityGroupsReady, Status: Unknown -> True
  Normal  InstanceProfileReady       5m44s  karpenter  Status condition transitioned, Type: InstanceProfileReady, Status: Unknown -> True
  Normal  ValidationSucceeded        5m31s  karpenter  Status condition transitioned, Type: ValidationSucceeded, Status: Unknown -> True
  Normal  Ready                      5m31s  karpenter  Status condition transitioned, Type: Ready, Status: Unknown -> True
```

檢查 NodePool：

```bash
kubectl describe nodepools.karpenter.sh default
```

**如果有錯誤，請檢查控制器日誌：**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**成功日誌範例：**
```json
{
  "level": "INFO",
  "time": "2026-01-11T16:30:19.194Z",
  "logger": "controller",
  "message": "discovered ssm parameter",
  "parameter": "/aws/service/eks/optimized-ami/1.34/amazon-linux-2023/arm64/nvidia/recommended/image_id",
  "value": "ami-0e8c1e804635db463"
}
```

**步驟 10：檢查 NodeClaim**

NodeClaim 是建立節點的請求。Karpenter 會建立 NodeClaim，接著將其轉換為實際的 EC2 執行個體：

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-c549s   t3a.small   spot       eu-central-1a   ip-10-10-15-190.eu-central-1.compute.internal   True    67s
```

**我們看到：**
- 已建立名為 `default-c549s` 的 NodeClaim
- 選擇了 `t3a.small` 類型的執行個體（2 vCPU、2GB RAM）
- 使用 spot 執行個體（較便宜）
- 節點位於 `eu-central-1a` 可用區域

**步驟 11：檢查應用程式 Pod**

現在 Pod 應該會成功啟動：

```bash
kubectl get po -n team-19
```

**結果：**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-6c59b6bf7b-m9plq   1/1     Running   0          17m
```

**狀態已變更為 `Running`！**

**步驟 12：檢查叢集節點**

查看叢集中的所有節點：

```bash
kubectl get no
```

**結果：**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   146m    v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   149m    v1.34.2-eks-b3126f4
ip-10-10-16-59.eu-central-1.compute.internal            Ready    <none>   9m13s   v1.34.2-eks-ecaa3a6
```

**請注意：**
- 前 3 個節點是 Fargate（供系統 Pod 使用）
- 最後一個節點是由 Karpenter 建立的 EC2 執行個體

### 檢查節點自動刪除

**步驟 13：刪除應用程式**

刪除我們的應用程式：

```bash
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**結果：**
```
namespace "team-19" deleted
deployment.apps "team19" deleted
service "team19" deleted
```

**步驟 14：檢查 Pod 刪除狀態**

```bash
kubectl get po -n team-19
```

**結果：**
```
No resources found in team-19 namespace.
```

**步驟 15：等待 NodeClaim 刪除**

等待約 30 秒（NodePool 中的 `consolidateAfter` 值），然後檢查：

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
No resources found
```

**Karpenter 已自動刪除 NodeClaim，因為節點變成空白！**

**步驟 16：檢查節點**

```bash
kubectl get no
```

**結果：**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-205.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-183.eu-central-1.compute.internal   Ready    <none>   152m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-196.eu-central-1.compute.internal   Ready    <none>   155m   v1.34.2-eks-b3126f4
```

**EC2 節點已刪除！只剩下 Fargate 節點。**

**結論：**Karpenter 會自動管理節點生命週期——在需要時建立，並在不再需要時刪除，藉此最佳化成本。

## 擴展應用程式

本節將學習 Karpenter 如何在負載增加時自動新增節點。

### 水平擴展

**步驟 1：部署測試應用程式**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/1.yaml
```

**步驟 2：檢查建立的資源**

檢查 NodeClaim：

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    6m6s
```

檢查節點：

```bash
kubectl get no
```

**結果：**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-15-87.eu-central-1.compute.internal    Ready    <none>   30m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-112.eu-central-1.compute.internal   Ready    <none>   32m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-72.eu-central-1.compute.internal    Ready    <none>   32m     v1.34.2-eks-b3126f4
ip-10-10-16-67.eu-central-1.compute.internal            Ready    <none>   6m34s   v1.34.2-eks-ecaa3a6
```

檢查 Pod：

```bash
kubectl get po -n team-19
```

**結果：**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-bzq77   1/1     Running   0          11m
```

### 自動新增節點

**步驟 3：擴展至 6 個副本**

增加應用程式副本數：

```bash
kubectl scale deployment -n team-19 team19 --replicas 6
```

**結果：**
```
deployment.apps/team19 scaled
```

**步驟 4：檢查 Pod 狀態**

```bash
kubectl get po -n team-19
```

**結果：**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          2m41s
team19-5d69f69559-bzq77   1/1     Running   0          17m
team19-5d69f69559-gpzgc   1/1     Running   0          2m41s
team19-5d69f69559-kxw6k   1/1     Running   0          2m41s
team19-5d69f69559-pc2dv   1/1     Running   0          2m41s
team19-5d69f69559-q6brn   1/1     Running   0          2m41s
```

**全部 6 個 Pod 都已成功啟動！**

**步驟 5：檢查 NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**請注意：**Karpenter 已自動新增第二個節點 (`default-gm8sj`)，因為一個節點不足以放置所有 6 個 Pod。

**步驟 6：擴展至 16 個副本**

進一步增加負載：

```bash
kubectl scale deployment -n team-19 team19 --replicas 16
```

**步驟 7：檢查 Pod 狀態**

```bash
kubectl get po -n team-19
```

**結果：**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          10m
team19-5d69f69559-4m772   0/1     Pending   0          2m37s
team19-5d69f69559-5ml7m   1/1     Running   0          2m37s
team19-5d69f69559-6dk8l   1/1     Running   0          2m37s
team19-5d69f69559-9qs2b   1/1     Running   0          2m37s
team19-5d69f69559-bzq77   1/1     Running   0          24m
team19-5d69f69559-fmcjq   1/1     Running   0          2m37s
team19-5d69f69559-gpzgc   1/1     Running   0          10m
team19-5d69f69559-kxw6k   1/1     Running   0          10m
team19-5d69f69559-ndg8q   1/1     Running   0          2m37s
team19-5d69f69559-pc2dv   1/1     Running   0          10m
team19-5d69f69559-q6brn   1/1     Running   0          10m
team19-5d69f69559-qgrqt   1/1     Running   0          2m37s
team19-5d69f69559-rss5s   1/1     Running   0          2m37s
team19-5d69f69559-x6qp8   1/1     Running   0          2m37s
team19-5d69f69559-z2wbm   0/1     Pending   0          2m37s
```

**問題：**部分 Pod 處於 `Pending` 狀態。為什麼？請移至下一節了解原因。

## 資源限制

本節將了解某些 Pod 為何仍處於 `Pending` 狀態，並學習如何管理 NodePool 中的資源限制。

### 設定 CPU 限制

**步驟 1：檢查目前的 NodePool 限制**

```bash
kubectl get nodepools.karpenter.sh default -o jsonpath='{.spec.limits}' | jq
```

**結果：**
```json
{
  "cpu": 4
}
```

**這表示：**NodePool 設定了 4 CPU 的限制。這代表此 pool 中所有節點的 CPU 總數不得超過 4 個核心。

**步驟 2：檢查現有 NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-gm8sj   t4g.small   spot       eu-central-1b   ip-10-10-16-66.eu-central-1.compute.internal   True    4m24s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal   True    15m
```

**分析：**
- 我們有 2 個 `t4g.small` 類型的節點
- 每個 `t4g.small` 有 2 vCPU
- 總計：2 個節點 × 2 vCPU = 4 vCPU
- **我們已達到限制！**Karpenter 無法建立更多節點。

### 診斷限制問題

**步驟 3：檢查 Karpenter 日誌**

看看控制器日誌怎麼說：

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq | grep ERROR -A 20
```

**結果：**
```json
{
  "level": "ERROR",
  "time": "2026-01-13T17:41:15.044Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "1ad0d78",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "0e86c755-4ab9-4d86-abb5-7e15e91241fc",
  "Pod": {
    "name": "team19-5d69f69559-4m772",
    "namespace": "team-19"
  },
  "NodePool": {
    "name": "default"
  },
  "error": "all available instance types exceed limits for nodepool (NodePool=default)"
}
```

**關鍵訊息：**`"all available instance types exceed limits for nodepool"`

這證實 Karpenter 因 CPU 限制而無法建立新節點。

**步驟 4：提高 CPU 限制**

將 CPU 限制提高至 6 個核心：

```bash
kubectl edit nodepools.karpenter.sh default
```

找到 `limits` 區段並變更值：

```yaml
spec:
  disruption:
    budgets:
    - nodes: 10%
    consolidateAfter: 30s
    consolidationPolicy: WhenEmptyOrUnderutilized
  limits:
    cpu: 4     # 變更為 6
```

儲存變更（在 vim 中使用 `:wq`，或在 nano 中使用 Ctrl+O、Enter、Ctrl+X）。

**步驟 5：檢查新節點建立情況**

等待幾秒鐘並檢查 NodeClaim：

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    19m
default-gpgn9   t4g.small   spot       eu-central-1b   ip-10-10-16-30.eu-central-1.compute.internal    True    66s
default-k4crl   t4g.small   spot       eu-central-1b   ip-10-10-16-67.eu-central-1.compute.internal    True    38m
```

**太好了！**Karpenter 已建立第三個節點 (`default-gpgn9`)。

**步驟 6：檢查應用程式 Pod**

```bash
kubectl get po -n team-19
```

**結果：**
```
NAME                      READY   STATUS    RESTARTS   AGE
team19-5d69f69559-4fmrc   1/1     Running   0          29m
team19-5d69f69559-4m772   1/1     Running   0          22m
team19-5d69f69559-5ml7m   1/1     Running   0          22m
team19-5d69f69559-6dk8l   1/1     Running   0          22m
team19-5d69f69559-9qs2b   1/1     Running   0          22m
team19-5d69f69559-bzq77   1/1     Running   0          44m
team19-5d69f69559-fmcjq   1/1     Running   0          22m
team19-5d69f69559-gpzgc   1/1     Running   0          29m
team19-5d69f69559-kxw6k   1/1     Running   0          29m
team19-5d69f69559-ndg8q   1/1     Running   0          22m
team19-5d69f69559-pc2dv   1/1     Running   0          29m
team19-5d69f69559-q6brn   1/1     Running   0          29m
team19-5d69f69559-qgrqt   1/1     Running   0          22m
team19-5d69f69559-rss5s   1/1     Running   0          22m
team19-5d69f69559-x6qp8   1/1     Running   0          22m
team19-5d69f69559-z2wbm   1/1     Running   0          22m
```

**現在所有 16 個 Pod 都處於 `Running` 狀態！**

### 檢查自動整併

**步驟 7：減少副本數**

將副本數減少至 3：

```bash
kubectl scale deployment -n team-19 team19 --replicas 3
```

**步驟 8：監控 Karpenter 日誌**

即時追蹤日誌：

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**您將看到整併訊息：**

```json
{
  "level": "INFO",
  "time": "2026-01-13T17:51:58.119Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "commit": "1ad0d78",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "delete",
  "disrupted-node-count": 1,
  "replacement-node-count": 0,
  "pod-count": 2,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-16-30.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-gpgn9"
      },
      "capacity-type": "spot",
      "instance-type": "t4g.small"
    }
  ]
}
```

**正在發生的事：**
- Karpenter 偵測到使用率不足的節點 (`underutilized`)
- 決定刪除節點 (`decision: delete`)
- 先以 `karpenter.sh/disrupted:NoSchedule` taint 標記節點
- 將 Pod 移至其他節點
- 刪除節點

**步驟 9：檢查剩餘節點**

等待約一分鐘後檢查：

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-927zs   t4g.small   spot       eu-central-1b   ip-10-10-16-179.eu-central-1.compute.internal   True    30m
```

**只剩下一個節點！**Karpenter 已移除多餘節點，最佳化了成本。

### 關於限制的其他資訊

可對不同資源類型設定限制：
- **cpu** — 處理器核心數
- **memory** — 記憶體容量
- **gpu** — GPU 數量（供 ML/AI 負載使用）
- **nodes** — 節點最大數量

**多個限制的設定範例：**

```yaml
limits:
  cpu: 100
  memory: 1000Gi
  nodes: 10
```

如需更多限制相關資訊，請參閱 [Karpenter 官方文件](https://karpenter.sh/docs/concepts/nodepools/#speclimits)。

## 節點生命週期管理 (Disruption)

Karpenter 透過 NodePool 規格中的 `consolidateAfter` 參數支援節點生命週期自動管理。

**核心概念：**

- **consolidateAfter** — 節點變成空白或使用率不足後，刪除前的等待時間
- **consolidationPolicy** — 整併策略：
  - `WhenEmpty` — 僅刪除完全空白的節點
  - `WhenEmptyOrUnderutilized` — 刪除空白與使用率不足的節點（建議使用）

**設定範例：**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s  # 釋放後 30 秒刪除
```

**運作方式：**

1. Karpenter 持續監控節點上的資源使用情況
2. 當節點變成空白或使用率不足時，Karpenter 啟動計時器
3. 若在指定時間 (`consolidateAfter`) 後節點仍不需要，Karpenter 會：
   - 以 `karpenter.sh/disrupted:NoSchedule` taint 標記節點
   - 優雅地將 Pod 移至其他節點
   - 刪除節點

**其他參數：**

```yaml
disruption:
  consolidationPolicy: WhenEmptyOrUnderutilized
  consolidateAfter: 30s
  budgets:
    - nodes: "10%"  # 同時刪除的節點不得超過 10%
```

如需更多 disruption 相關資訊，請參閱[官方文件](https://karpenter.sh/docs/concepts/disruption/)。

---

## 節點大小最佳化 (RightSizing)

Karpenter 會依據 Pod 需求自動選擇最佳節點大小。這稱為「right-sizing」——選擇最適當且最經濟的執行個體類型。

### 自動選擇最佳大小

**步驟 1：設定 CPU 限制**

將 NodePool 限制提高至 10 個核心：

```bash
kubectl edit nodepools.karpenter.sh default
```

變更：

```yaml
spec:
  limits:
    cpu: 6     # 變更為 10
```

**步驟 2：部署具備大量需求的應用程式**

部署一個請求 3 CPU 的應用程式：

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**步驟 3：檢查建立的 NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-6ltdb   t3.xlarge   spot       eu-central-1a   ip-10-10-15-179.eu-central-1.compute.internal   True    117s
```

**請注意：**由於 Pod 請求 3 CPU，Karpenter 選擇具有 4 vCPU 的 `t3.xlarge` 執行個體。

**步驟 4：檢查節點詳細資料**

```bash
kubectl get no ip-10-10-15-179.eu-central-1.compute.internal -o yaml
```

**重要標籤：**

```yaml
labels:
  karpenter.k8s.aws/instance-cpu: "4"
  karpenter.k8s.aws/instance-type: t3.xlarge
  karpenter.k8s.aws/instance-category: t
  karpenter.sh/capacity-type: spot
```

### 需求變更時替換節點

**步驟 5：降低 Pod 需求**

變更 deployment 中的 CPU 需求：

```bash
kubectl edit deployments.apps -n team-19 team19
```

找到 `resources` 區段並變更：

```yaml
spec:
  containers:
  - image: viktoruj/ping_pong:alpine
    name: app
    resources:
      requests:
        cpu: "3"      # 變更為 "50m"（50 millicores）
        memory: 500Mi
```

儲存變更。

**步驟 6：監控 Karpenter 日誌**

```bash
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter -f | jq
```

**您將看到：**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.171Z",
  "logger": "controller",
  "message": "disrupting node(s)",
  "controller": "disruption",
  "reason": "underutilized",
  "decision": "replace",
  "disrupted-node-count": 1,
  "replacement-node-count": 1,
  "pod-count": 1,
  "disrupted-nodes": [
    {
      "Node": {
        "name": "ip-10-10-15-179.eu-central-1.compute.internal"
      },
      "NodeClaim": {
        "name": "default-6ltdb"
      },
      "capacity-type": "spot",
      "instance-type": "t3.xlarge"
    }
  ],
  "replacement-nodes": [
    {
      "capacity-type": "spot",
      "instance-types": "t4g.small, t3.small, t3a.small, m8gd.medium, r7gd.medium and 10 other(s)"
    }
  ]
}
```

**正在發生的事：**
- Karpenter 偵測到節點使用率不足 (`underutilized`)
- 決定替換節點 (`decision: replace`)
- 建立新的、更便宜的節點

**建立新的 NodeClaim：**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:07.219Z",
  "logger": "controller",
  "message": "created nodeclaim",
  "controller": "disruption",
  "NodeClaim": {
    "name": "default-48ck8"
  },
  "requests": {
    "cpu": "200m",
    "memory": "50Mi",
    "pods": "4"
  },
  "instance-types": "m6g.medium, m6gd.medium, m7g.medium, m8g.medium, m8gd.medium and 10 other(s)"
}
```

**啟動新的執行個體：**

```json
{
  "level": "INFO",
  "time": "2026-01-14T18:38:10.582Z",
  "logger": "controller",
  "message": "launched nodeclaim",
  "provider-id": "aws:///eu-central-1b/i-0f0d32ba789615574",
  "instance-type": "t4g.small",
  "zone": "eu-central-1b",
  "capacity-type": "spot",
  "allocatable": {
    "cpu": "1930m",
    "memory": "1359Mi"
  }
}
```

**步驟 7：檢查新的 NodeClaim**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME            TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
default-48ck8   t4g.small   spot       eu-central-1b   ip-10-10-16-44.eu-central-1.compute.internal   True    8m59s
```

**太好了！**Karpenter 已將 `t3.xlarge` (4 vCPU) 替換為 `t4g.small` (2 vCPU)，成本顯著更低。

**步驟 8：清理**

刪除 deployment：

```bash
kubectl delete deployments.apps -n team-19 team19
```

等待 NodeClaim 刪除：

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
No resources found
```

**結論：**Karpenter 會自動最佳化節點大小，選擇符合應用程式需求且最經濟的選項。

## 節點設定更新 (Drift)

Drift 是在 EC2NodeClass 設定變更時自動更新節點的機制。當您變更 AMI、security groups、user data 或其他參數時，Karpenter 會自動以具更新設定的新節點替換現有節點。

### 更新 AMI 映像

**步驟 1：取得先前 EKS 版本的 AMI**

取得 EKS 1.33 版本的 AMI ID：

```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.33/amazon-linux-2023/x86_64/standard/recommended/image_id \
  --query "Parameter.Value" \
  --output text
```

**結果：**
```
ami-0fc1cdef3ebc3a8fe
```

**步驟 2：在 EC2NodeClass 中設定舊 AMI**

編輯 EC2NodeClass：

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

找到 `amiSelectorTerms` 區段並變更：

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # 原本設定
```

為：

```yaml
spec:
  amiFamily: AL2023
  amiSelectorTerms:
  - id: "ami-0fc1cdef3ebc3a8fe"  # 1.33 版本的特定 AMI ID
```

**步驟 3：部署應用程式**

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/02/worker/files/tasks/2.yaml
```

**步驟 4：檢查節點版本**

```bash
kubectl get no
```

**結果：**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   60m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   58m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   2m23s v1.33.5-eks-ecaa3a6   <-- 1.33 版本！
```

**請注意：**該節點使用 Kubernetes 1.33.5 版本（來自舊 AMI）。

### 自動遷移至新版本

**步驟 5：恢復 AMI 自動選擇**

將 EC2NodeClass 編輯回原狀：

```bash
kubectl edit ec2nodeclasses.karpenter.k8s.aws default
```

變更為：

```yaml
spec:
  amiSelectorTerms:
  - alias: al2023@latest  # 自動選擇最新版本
```

**正在發生的事：**
- Karpenter 偵測到 EC2NodeClass 的變更
- 判定現有節點使用過時設定 (drift)
- 自動建立使用更新 AMI 的新節點
- 優雅地將 Pod 移至新節點
- 刪除舊節點

**步驟 6：檢查節點更新**

等待約一分鐘，然後檢查節點：

```bash
kubectl get no
```

**結果（約 30 秒後）：**
```
NAME                                                    STATUS   ROLES    AGE   VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   89m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   87m   v1.34.2-eks-b3126f4
ip-10-10-15-175.eu-central-1.compute.internal           Ready    <none>   33s   v1.34.2-eks-ecaa3a6   <-- 新版本！
```

**結果（約 4 分鐘後）：**
```
NAME                                                    STATUS   ROLES    AGE     VERSION
fargate-ip-10-10-16-114.eu-central-1.compute.internal   Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-23.eu-central-1.compute.internal    Ready    <none>   93m     v1.34.2-eks-b3126f4
fargate-ip-10-10-16-52.eu-central-1.compute.internal    Ready    <none>   91m     v1.34.2-eks-b3126f4
ip-10-10-16-230.eu-central-1.compute.internal           Ready    <none>   4m22s   v1.34.2-eks-ecaa3a6
```

**太好了！**Karpenter 已自動以更新 AMI 版本 (1.34.2) 的新節點替換了該節點。

**步驟 7：清理**

```bash
kubectl delete deployments.apps -n team-19 team19
```

等待 NodeClaim 刪除：

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
No resources found
```

**結論：**Drift 可讓您在設定變更時無須手動介入即可自動更新節點。這尤其適用於：
- 更新 AMI（安全性修補、Kubernetes 新版本）
- 變更 security groups
- 更新 user data 指令碼
- 變更 IAM 角色

---

## 使用多個 NodePool

在 production 環境中，通常需要依不同節點群組分隔負載。例如：
- 專用節點上的 Ingress 控制器
- 用於週期性工作 (jobs) 的高效能節點
- 用於 ML/AI 負載的 GPU 節點
- 供資料庫使用的大記憶體節點

### 透過 Taints 與 Tolerations 隔離負載

**情境：**我們需要執行具有高資源需求（CPU、記憶體、GPU）的週期性 job。

**需求：**
1. 一般 Pod 不得被排程至這些節點（僅限 job）
2. job 在節點上執行時，不應進行整併
3. job 一完成，節點就應刪除

### Job 的專用節點

**步驟 1：建立專用 NodePool**

```bash
cat <<EoF> job-nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: job
spec:
  template:
    metadata:
      labels:
        work_type: "job_karpenter"  # 用於識別的標籤
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64","arm64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["t", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
        - key: "karpenter.k8s.aws/instance-size"
          operator: In
          values: ["small","medium","large", "xlarge"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: job
      expireAfter: 720h # 30 天
      # 重要：Taint 可防止一般 Pod 在這些節點上執行
      taints:
        - key: workType
          value: "job"
          effect: NoSchedule  # 沒有相應 toleration 的 Pod 無法啟動
  limits:
    cpu: 6
  disruption:
    consolidationPolicy: WhenEmpty  # 僅刪除空白節點（不會在 job 執行期間刪除）
    consolidateAfter: 10s           # job 完成後快速刪除
EoF

kubectl apply -f job-nodepool.yaml
```

**與 default NodePool 的主要差異：**

1. **Taints** — 防止一般 Pod 啟動：
   ```yaml
   taints:
     - key: workType
       value: "job"
       effect: NoSchedule
   ```

2. **consolidationPolicy: WhenEmpty** — 僅當節點完全空白時才刪除（不會中斷正在執行的 job）

3. **consolidateAfter: 10s** — 完成後快速刪除

**步驟 2：從 Terraform 輸出取得參數**

在輸出中找到：

```bash
# 範例：
# eks_name = "eks2-viktor-01"
# karpenter_node_iam_role_name = "Karpenter-eks2-viktor-01-20260111144312385200000005"
```

**步驟 3：建立 job 的 EC2NodeClass**

```bash
cat <<EoF> job-nodeclass.yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: job
spec:
  role: "Karpenter-eks2-viktor-01-20260111144312385200000005"  # 替換為您的值
  amiSelectorTerms:
    - alias: "al2023@latest"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 替換為您的叢集名稱
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "eks2-viktor-01"  # 替換為您的叢集名稱
  tags:
      Name: "eks2-viktor-01-job"  # 替換為您的叢集名稱
      team: "infra"
      work_type: "job"
      operation: "my eks lab"
      city: "myCity"
      resource_type: "dynamic"
      karpenter.sh/discovery: eks2-viktor-01
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeType: gp3
        volumeSize: 25Gi
        iops: 3000
        throughput: 125
        encrypted: true
        deleteOnTermination: true
EoF

kubectl create -f job-nodeclass.yaml
```

**步驟 4：檢查資源狀態**

```bash
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

**結果：**
```
NAME      READY   AGE
default   True    8m10s
job       True    2m22s
```

```bash
kubectl get nodepools.karpenter.sh
```

**結果：**
```
NAME      NODECLASS   NODES   READY   AGE
default   default     0       True    9m30s
job       job         0       True    3m38s
```

**若狀態不是 READY**，請進行診斷：

```bash
kubectl describe ec2nodeclasses.karpenter.k8s.aws job
kubectl describe nodepools.karpenter.sh job
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | jq
```

**步驟 5：使用 Toleration 執行 Job**

建立可於具有 `workType=job` taint 之節點上執行的 job：

```bash
cat <<EoF> test-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: testjob
spec:
  template:
    spec:
      # Toleration 允許 Pod 在具有相應 taint 的節點上啟動
      tolerations:
      - key: workType
        operator: Equal
        value: job
        effect: NoSchedule
      # Affinity 確保 Pod 只會在 job NodePool 的節點上啟動
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: work_type
                operator: In
                values:
                - job_karpenter
      containers:
      - name: job-container
        image: busybox
        command: ["sh", "-c", "echo 'Job started'; sleep 30; echo 'Job completed'"]
      restartPolicy: Never
  backoffLimit: 1
EoF

kubectl apply -f test-job.yaml
```

**步驟 6：檢查 NodeClaim 建立情況**

```bash
kubectl get nodeclaims.karpenter.sh
```

**結果：**
```
NAME        TYPE        CAPACITY   ZONE            NODE                                           READY   AGE
job-mpt7v   t4g.small   spot       eu-central-1b   ip-10-10-16-18.eu-central-1.compute.internal   True    58s
```

**檢查 Pod：**

```bash
kubectl get po
```

**結果（執行期間）：**
```
NAME            READY   STATUS    RESTARTS   AGE
testjob-gtlbk   1/1     Running   0          64s
```

**結果（完成後）：**
```
NAME            READY   STATUS      RESTARTS   AGE
testjob-gtlbk   0/1     Completed   0          72s
```

**檢查節點：**

```bash
kubectl get no
```

**結果：**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   130m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   128m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   130m   v1.34.2-eks-b3126f4
ip-10-10-16-18.eu-central-1.compute.internal            Ready    <none>   59s    v1.34.2-eks-ecaa3a6
```

**步驟 7：檢查節點自動刪除**

在 job 完成後等待約 10-15 秒，然後檢查節點：

```bash
kubectl get no
```

**結果：**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**節點已成功刪除！**Karpenter 在 job 完成後 10 秒自動刪除了節點。

**結論：**使用具有 taints 與 tolerations 的多個 NodePool 可讓您：
- 隔離不同類型的負載
- 最佳化成本（job 完成後快速刪除節點）
- 防止一般 Pod 在專用節點上啟動
- 為不同類型負載靈活管理整併策略

## 清理資源

完成實驗後，必須刪除所有建立的資源，以避免不必要的費用。

**步驟 1：確認沒有作用中的 NodeClaim**

確認沒有作用中的 NodeClaim：

```bash
kubectl get nodeclaims.karpenter.sh
```

**預期結果：**
```
No resources found
```

**若有作用中的 NodeClaim：**

1. 檢查節點上是否有執行中的 Pod：

```bash
kubectl get pods --all-namespaces -o wide
```

2. 刪除 deployment、pods 或 jobs：

```bash
# deployment 刪除範例
kubectl delete deployment -n team-19 team19

# job 刪除範例
kubectl delete job testjob
```

3. 刪除 Pod 後，手動刪除 NodeClaim（如有需要）：

```bash
kubectl delete nodeclaim <name-of-nodeclaim>
```

**步驟 2：檢查叢集節點**

確認僅剩 Fargate 節點：

```bash
kubectl get no
```

**預期結果：**
```
NAME                                                    STATUS   ROLES    AGE    VERSION
fargate-ip-10-10-15-110.eu-central-1.compute.internal   Ready    <none>   133m   v1.34.2-eks-b3126f4
fargate-ip-10-10-15-71.eu-central-1.compute.internal    Ready    <none>   131m   v1.34.2-eks-b3126f4
fargate-ip-10-10-16-96.eu-central-1.compute.internal    Ready    <none>   133m   v1.34.2-eks-b3126f4
```

**所有節點都必須以 `fargate-` 開頭。**

**步驟 3：刪除基礎設施**

刪除為實驗建立的所有資源：

```bash
TASK=02 make delete_eks_task
```

**命令輸出：**

```
16:14:15.750 INFO   The stack at . will be processed in the following order for command destroy:
Group 1
- Module ./worker

Group 2
- Module ./eks_karpenter
- Module ./ssh-keys

Group 3
- Module ./eks_addons

Group 4
- Module ./eks_fargate_system

Group 5
- Module ./eks_control_plane

Group 6
- Module ./vpc


WARNING: Are you sure you want to run `terragrunt destroy` in each folder of the stack described above? There is no undo! (y/n)
```

**輸入 `y` 以確認刪除。**

**將會刪除：**
- 工作節點 (worker)
- Karpenter 控制器與相關資源
- SSH 金鑰
- EKS add-ons
- Fargate profile
- EKS Control Plane
- VPC 與網路基礎設施

**刪除程序約需 10-15 分鐘。**

---

## 結論

恭喜！您已成功完成 Karpenter 基礎實驗。

**您學習了：**

1. **基本設定** — 建立 NodePool 與 EC2NodeClass 以自動管理節點
2. **自動擴縮** — Karpenter 在負載增加時動態新增節點
3. **限制管理** — 透過 limits 控制資源最大數量
4. **整併** — 自動刪除空白及使用率不足的節點以最佳化成本
5. **Right-sizing** — 依 Pod 需求自動選擇最佳節點大小
6. **Drift** — 設定變更時自動更新節點（AMI、security groups 等）
7. **多個 NodePool** — 透過 taints、tolerations 與 affinity 隔離不同類型負載

**Karpenter 的主要優點：**

- **快速擴縮** — 節點在數秒內建立，而非數分鐘
- **成本最佳化** — 自動選擇最經濟的執行個體類型
- **彈性** — 支援 spot 與 on-demand 執行個體、不同架構 (amd64, arm64)
- **簡易性** — 透過 Kubernetes 資源宣告式設定
- **自動化** — 對節點管理所需的手動介入極少

**其他資源：**

- [Karpenter 官方文件](https://karpenter.sh/docs/)
- [Karpenter Best Practices](https://karpenter.sh/docs/concepts/nodepools/#best-practices)
- [Troubleshooting Guide](https://karpenter.sh/docs/troubleshooting/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

**後續步驟：**

- 探索 Karpenter 的進階功能（weighted NodePools、custom AMI、GPU support）
- 將 Karpenter 整合至您的 production 應用程式
- 為 Karpenter 設定監控與告警
- 透過分析 spot 與 on-demand 執行個體的使用情況來最佳化成本
