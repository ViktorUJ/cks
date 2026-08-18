[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 101 - 參考解答(集群即代碼:存取、計算、網路、AMI)

所有命令都在工作機(worker)上透過 SSH 執行。kubectl 已經配置好指向集群(kubeconfig 是
機器啟動時透過 `aws eks update-kubeconfig` 組裝的)。

## 任務 1。Namespace `eks-101`

```bash
kubectl create namespace eks-101
```

## 任務 2。Deployment `web`(viktoruj/ping_pong,3 個副本)在 EC2 節點上

系統 Pod(kube-system、karpenter)運行在 Fargate 上,而普通 namespace 中的任何 Pod 都會
被排程到 Karpenter 建立的 EC2 節點上。因此 `eks-101` 中的 Deployment 會自動落在 EC2 上:

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3 -n eks-101
kubectl rollout status deployment/web -n eks-101
```

檢查 Pod 沒有落在 Fargate 上(節點名稱以 `ip-` 開頭,而不是 `fargate-`):

```bash
kubectl get po -n eks-101 -l app=web -o wide
```

原因:Fargate 只有在 Pod 的 namespace 符合某個 Fargate profile 時才會運行該 Pod。在這個
實驗中,profile 是為 `kube-system` 和 `karpenter` 配置的,`eks-101` 沒有對應的 profile,
因此 `eks-101` 的負載由 Karpenter(EC2)承擔。你將在任務 7 中記錄這個解釋。

## 任務 3。產物:系統節點與工作節點的分離

保存節點列表,標明哪些是 Fargate,哪些是 EC2:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -o wide > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt
```

檔案中應同時包含 `fargate-...` 節點(系統 Pod)和 `ip-...` 節點(Karpenter 工作節點)。
這正是第 9 章討論的計算分離。

## 任務 4。產物:來自 VPC CIDR 的 Pod IP

VPC CNI 會為 Pod 分配來自節點所在子網(`10.10.15.0/24` 或 `10.10.16.0/24`)的可路由位
址,也就是來自 VPC `10.10.0.0/16`:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].status.podIP}' \
  > /var/work/tests/artifacts/4/podip.txt
echo >> /var/work/tests/artifacts/4/podip.txt
cat /var/work/tests/artifacts/4/podip.txt
```

為了更好地理解 VPC CNI,可以將 Pod 的位址與私有子網的 CIDR 進行比對(Pod 從其所在節點
的子網中獲得了 IP):

```bash
VPC=$(aws eks describe-cluster --name "$(kubectl config current-context | sed 's|.*/||')" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[CidrBlock,AvailabilityZone]' --output table
```

## 任務 5。產物:工作節點的 AMI(AL2023)

查看任意工作(EC2)節點的作業系統映像。預設的 NodePool 基於 `al2023@latest` 構建,所以
是 Amazon Linux 2023:

```bash
mkdir -p /var/work/tests/artifacts/5
NODE=$(kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.status.nodeInfo.osImage}' \
  > /var/work/tests/artifacts/5/ami.txt
echo >> /var/work/tests/artifacts/5/ami.txt
cat /var/work/tests/artifacts/5/ami.txt
```

## 任務 6。Deployment `batch`(帶 CPU request 的 6 個副本) - 透過 Karpenter 擴展規模

帶有明確 requests 的負載會讓 Karpenter 添加計算資源。我們創建帶有 CPU request 的
deployment 並等待所有副本就緒:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch
  namespace: eks-101
spec:
  replicas: 6
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/batch -n eks-101
```

可以這樣觀察 Karpenter 建立節點的過程:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type=default -o wide
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | tail -n 20
```

## 任務 7。職責邊界:症狀與解釋

故意在 Fargate 不存在的地方請求它。Pod 應該卡在 `Pending`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-probe
  namespace: eks-101
spec:
  nodeSelector:
    eks.amazonaws.com/compute-type: fargate
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get po fg-probe -n eks-101 -o wide
kubectl describe po fg-probe -n eks-101 | sed -n '/Events/,$p'
# 按時間順序查看整個 namespace 的事件 - 這是診斷排程失敗的 SRE 技能
kubectl get events -n eks-101 --sort-by='.metadata.creationTimestamp'
```

Pod 停留在 `Pending`:因為 `eks-101` 沒有 Fargate profile,所以 EKS 不會將 Pod 排程到
Fargate 上,而 Karpenter 也不會建立 EC2 節點,因為它的節點不帶有
`eks.amazonaws.com/compute-type: fargate` 這個 label。沒有人能滿足這個要求。

將解釋保存為產物:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/whyfargate.txt <<'EOF'
web 和 batch 的 Pod 落在了 Karpenter 的 EC2 節點上,而不是 Fargate:Fargate 只有在 Pod 的
namespace 符合某個 profile 時才會運行該 Pod。集群中存在 kube-system 和 karpenter 的
profile,但沒有 eks-101 的 profile。

fg-probe 卡在 Pending 中,因為它明確請求了 Fargate(nodeSelector
eks.amazonaws.com/compute-type: fargate),但 eks-101 沒有 profile,而 Karpenter 的 EC2
節點也不帶這個 label。無論是 Fargate 還是 Karpenter 都無法滿足這個要求。
EOF
cat /var/work/tests/artifacts/7/whyfargate.txt
```

職責邊界一目了然:哪些 namespace 落在 Fargate 上,是由你決定的(透過 Fargate profile,
第 9 章),而不是 EKS「自己」決定的。

## 快速檢查

```bash
check_result
```
