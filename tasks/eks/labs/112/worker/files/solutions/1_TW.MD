[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 112 - 參考解答(Fargate:配置檔、限制、成本)

所有命令都在工作機上透過 SSH 執行。kubectl 已經配置好指向集群(kubeconfig 是在機器啟
動時透過 `aws eks update-kubeconfig` 組裝的)。供 namespace `eks-112` 使用的 Fargate 配
置檔 `workload` 已經由實驗的基礎設施創建完成 - 學生只需要創建 namespace 以及其中的對
象。

## 任務 1. Namespace `eks-112`

```bash
kubectl create namespace eks-112
```

`workload` 配置檔透過 `namespace = eks-112` 匹配,沒有 `labels`,所以整個 namespace 會
完全落到 Fargate 上 - 其中不會有任何例外。

## 任務 2. Fargate 上的 Guaranteed Pod `fg-app`

Fargate 只運行 `requests` 等於 `limits` 的 Pod(`Guaranteed` 類別)。我們創建一個帶有
明確相等值的 Deployment:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
```

檢查 Pod 是否落在 Fargate 節點上(節點名稱以 `fargate-` 開頭,而不是 `ip-`):

```bash
kubectl get po -n eks-112 -l app=fg-app -o wide
```

## 任務 3. 產物:實際分配到的容量

Fargate 會把請求的總和向上取整到一個固定的 vCPU/記憶體組合,並為 Kubernetes 元件
(`kubelet`、`kube-proxy`、`containerd`)額外加上 `256 MB`。實際分配到的容量可以在
`CapacityProvisioned` 注解中看到:

```bash
mkdir -p /var/work/tests/artifacts/3
POD=$(kubectl get po -n eks-112 -l app=fg-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n eks-112 \
  -o jsonpath='{.metadata.annotations.CapacityProvisioned}' \
  > /var/work/tests/artifacts/3/capacity.txt
echo >> /var/work/tests/artifacts/3/capacity.txt
cat /var/work/tests/artifacts/3/capacity.txt
```

對於 `500m` CPU 和 `1Gi` 記憶體的請求,再加上 `256 MB` 的額外開銷,Fargate 會選擇最接近
的匹配組合(例如 `0.5vCPU 1GB`,或者如果加上額外開銷後總記憶體超過 `1 GB`,則是
`0.5vCPU 2GB`) - `kubectl describe pod` 顯示的正是這一行。

## 任務 4. 症狀:privileged Pod 無法啟動

Fargate 嚴格禁止 privileged 容器、DaemonSet、hostNetwork/hostPort、hostPath 以及 GPU。
我們嘗試在 `eks-112` 中創建一個 privileged Pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-privileged
  namespace: eks-112
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
    securityContext:
      privileged: true
EOF

kubectl get po fg-privileged -n eks-112
kubectl describe po fg-privileged -n eks-112 | sed -n '/Events/,$p'
```

該 Pod 不會進入 `Running` 狀態:Fargate 在 admission(准入)階段就拒絕了 privileged
容器,這一點可以從 Pod 的 events 中看到。我們把解釋保存為產物:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/privileged.txt <<'EOF'
Pod fg-privileged 無法啟動,因為它請求了 privileged: true。Fargate 不支援 privileged
容器:這是這個模式的其中一項嚴格限制,與 DaemonSet、hostNetwork/hostPort、hostPath 和
GPU 並列。這個錯誤在 Pod 的 events 中表現為 admission 被拒絕,而不是因資源不足導致的
一般 Pending。
EOF
cat /var/work/tests/artifacts/4/privileged.txt
```

我們可以移除這個 Pod,避免它影響後續的檢查:

```bash
kubectl delete pod fg-privileged -n eks-112
```

## 任務 5. 將暫存磁碟擴展到 30Gi

預設情況下 Fargate 提供 `20 GiB` 的暫存磁碟,透過 `resources` 中的 `ephemeral-storage`
最多可擴展到 `175 GiB`(requests 必須等於 limits,Pod 仍保持 Guaranteed)。我們更新
`fg-app`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
kubectl get po -n eks-112 -l app=fg-app -o wide
```

Pod 正常啟動:`30Gi` 在允許的 `175 GiB` 範圍內,並且滿足了 `requests == limits` 的要
求。

## 任務 6. 成本結構:Fargate 對比 node group

關鍵的差異在於計費單位。Fargate 按某個具體 Pod 的 vCPU 和記憶體、按其生命週期收費;
node group 則按整個 EC2 instance 收費,無論它的負載有多高。這個產物的自動檢查會在檔案
中尋找詞 `pod`,緊鄰 `vCPU`,所以下面的產物同時包含兩者:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/costmodel.txt <<'EOF'
Fargate 是按 pod 自身的 vCPU 和記憶體、按它實際運行的時間收費:如果 pod 沒有運
行,就不會產生費用,也絕不會為閒置容量多付錢。node group 則相反,是按整個 instance 收
費:即使節點在 pod 之間閒置或未被充分利用,也要為那段時間付費。就單位資源而言,
Fargate 通常比 node group 節點上等量的資源更貴,所以最終的經濟性取決於利用率:在負載
高且可預測的情況下,node group 更划算;而在需求波動大或難以預測的情況下,Fargate 可以
避免為閒置的 instance 多付錢。
EOF
cat /var/work/tests/artifacts/6/costmodel.txt
```

## 快速檢查

```bash
check_result
```
