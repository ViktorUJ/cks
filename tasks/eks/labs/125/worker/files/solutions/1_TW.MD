[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 125 - 參考解答（EKS Auto Mode 對比自建技術棧）

所有指令都在 worker 機器上透過 SSH 執行。kubectl 已經針對這個叢集設定好了。這個叢集是以
啟用 Auto Mode 和一個內建 NodePool `general-purpose` 建立的 - 這個 lab 中沒有 Fargate
profile、managed addon，也沒有 Karpenter。

我們從 kubeconfig 取得叢集名稱：`list-clusters[0]` 會回傳帳戶中的第一個叢集，那未必是
我們的。

```bash
export CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
echo "$CLUSTER"
```

## 任務 1. 確認模式：Auto Mode 已啟用

```bash
mkdir -p /var/work/tests/artifacts/1
{
  echo "=== aws eks describe-cluster computeConfig ==="
  aws eks describe-cluster --name "$CLUSTER" --query 'cluster.computeConfig'
  echo
  echo "=== kubectl get nodepools ==="
  kubectl get nodepools
} > /var/work/tests/artifacts/1/automode.txt
cat /var/work/tests/artifacts/1/automode.txt
```

`computeConfig.enabled` 必須是 `true`，且 `nodePools` 必須包含 `general-purpose`。
`kubectl get nodepools` 把同一個 NodePool 顯示為普通的 Kubernetes 資源 - Auto Mode
透過 Kubernetes API 把已啟用的內建 pool 具體化（第 9 章）。

## 任務 2. 第二個內建 NodePool 已停用

```bash
kubectl get nodepools
```

清單中沒有 `system` - 內建 NodePool 只有在其名稱出現在 `computeConfig.nodePools` 時，
才會作為叢集資源出現；在這個 lab 中，那裡只列出了 `general-purpose`。

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/twopools.txt <<'EOF'
EKS Auto Mode 有兩個內建 NodePool：general-purpose 和 system。system NodePool 帶有
CriticalAddonsOnly taint，會被對叢集至關重要的元件（例如 CoreDNS）容忍 - 這是把它們與
一般工作負載分開的方式，讓它們不與應用程式爭奪資源，也不會在 general-purpose 節點整併
時被驅逐。

在這個 lab 中，node_pools 只包含 general-purpose，因此 system 不會作為叢集資源被建立：
kubectl get nodepools 不會顯示它。啟用它意味著在 control plane 上編輯
computeConfig.nodePools，而不是用 kubectl 建立一個物件。
EOF
cat /var/work/tests/artifacts/2/twopools.txt
```

## 任務 3. general-purpose 上的工作負載，以及嘗試修改內建 NodePool

```bash
kubectl create namespace eks-125
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-125
kubectl rollout status deployment/web -n eks-125

kubectl get pods -n eks-125 -o wide
```

兩個副本都會在 Auto Mode 自己於 `general-purpose` 下拉起的節點上進入 `Running` -
不需要 Fargate profile，也不需要外部 Karpenter，而 lab 101 的基礎架構需要這些。

我們嘗試編輯內建 NodePool。AWS 文件把內建 NodePool 描述為「enabled or disabled but not
modified」，但這需要親自動手驗證 - admission 層級並沒有禁止：

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "=== 對內建 pool 執行 kubectl patch ==="
  kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":{"cpu":"100"}}}'
  echo "修改後的 limits：$(kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}')"
  echo
  echo "=== 這個物件屬於誰 ==="
  kubectl get nodepool general-purpose -o jsonpath='labels={.metadata.labels}{"\n"}'
  kubectl get nodepool general-purpose \
    -o jsonpath='managedFields managers={range .metadata.managedFields[*]}{.manager}{","}{end}{"\n"}'
  echo
  echo "=== 結論 ==="
  echo "修改被接受了：指令回傳了 patched，值也留在物件裡。但這個物件屬於服務："
  echo "標籤 app.kubernetes.io/managed-by=eks，欄位由 manager eks-auto-mode 擁有。"
  echo "唯一受支援的管理方式是在 computeConfig.nodePools 中啟用和停用 pool 名稱。"
  echo "改變這個清單會把資源連同它的節點一起刪除，然後從頭重建，不保留我們的修改。"
} > /var/work/tests/artifacts/3/builtin.txt
cat /var/work/tests/artifacts/3/builtin.txt
```

把 pool 還原到原始狀態 - 我們不需要在不屬於自己的物件上留一個多餘的 `limits`：

```bash
kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":null}}'
kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}{"\n"}'
```

注意：`kubectl delete nodepool general-purpose` 也能執行，但 EKS 不會重新建立這個物件，
而 pool 的節點卻會被 drain - 叢集會失去計算資源。復原只能透過 `computeConfig`（配方在
README 的「刪除」部分）。

## 任務 4. 無法存取節點：SSH 和 SSM 依設計被關閉

在 Auto Mode 中，節點名稱本身就是 instance ID，不需要另外解析 `providerID`：

```bash
NODE=$(kubectl get pods -n eks-125 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node=$NODE"
```

我們收集三項證據。第一 - 這個 instance 沒有 key pair（`KeyName`），所以無論是否有東西
在監聽 22 埠，用金鑰進行 SSH 都是不可能的：

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "=== key pair 和節點 image ==="
  aws ec2 describe-instances --instance-ids "$NODE" \
    --query 'Reservations[0].Instances[0].[KeyName,ImageId,PlatformDetails]' --output text
  echo "KeyName 是空的（None）- 這個節點沒有 key pair"
  echo
  echo "=== SSM：沒有連線 ==="
  aws ssm get-connection-status --target "$NODE" --output json
  echo "SSM 清單（這個節點不應該在裡面）："
  aws ssm describe-instance-information \
    --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
} > /var/work/tests/artifacts/4/nossh.txt
```

這裡不要用 `aws ssm start-session`：worker 機器沒有 `ssm:StartSession` 權限，所以這個
指令會回傳 `AccessDeniedException` - 這是關於 worker 政策的事實，不是關於節點的。
`get-connection-status` 回傳的 `notconnected` 狀態才是這個任務問題的答案。

第三項證據方向相反：主機並沒有和叢集隔離。一個帶有 `hostPath` 掛載 `/` 的特權 pod
可以讀取節點的檔案系統：

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostprobe
  namespace: eks-125
spec:
  nodeName: $NODE
  restartPolicy: Never
  containers:
  - name: p
    image: busybox
    command: ["sh","-c","cat /host/etc/os-release; echo ---; ls /host/bin | head -5"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: h
      mountPath: /host
  volumes:
  - name: h
    hostPath:
      path: /
EOF

kubectl wait --for=condition=Ready pod/hostprobe -n eks-125 --timeout=90s 2>/dev/null
sleep 5
{
  echo
  echo "=== 從特權 pod 看到的主機 ==="
  kubectl logs hostprobe -n eks-125
  echo
  echo "=== 結論 ==="
  echo "SSH 不可能（沒有 KeyName key pair），SSM 沒有連線（notconnected）-"
  echo "operator 對節點沒有存取權。但 Bottlerocket image 可以從特權 pod 中讀取："
  echo "Auto Mode 關閉了 operator 的門，不是 cluster-admin 的門。後者由"
  echo "Pod Security Admission 和 admission 政策負責（第 19 和 22 章）。"
} >> /var/work/tests/artifacts/4/nossh.txt

kubectl delete pod hostprobe -n eks-125
cat /var/work/tests/artifacts/4/nossh.txt
```

Auto Mode 節點是 Bottlerocket，具有 read-only root 和 enforcing 模式的 SELinux，沒有
shell 也沒有套件管理器，節點最長存活 21 天並自動替換（第 9 章）。用習慣的 SSH 和 SSM
工具進行除錯，原則上是不可能的 - 這就是最小化維運的代價。

## 任務 5. 帶有明確 limits 的自建 NodePool

內建 pool 沒有 `limits` - 在需求無限增長的情況下，它們會沒有上限地成長（第 9 章，
第 9.7 節）。你自己的 NodePool 參照內建的 `NodeClass` `default`，並自己設定限制：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: custom-limited
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["c", "m", "r"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
  limits:
    cpu: "10"
    memory: 10Gi
EOF

kubectl get nodepool custom-limited
```

自建的 NodePool 不會繼承內建 pool 的限制（僅 C/M/R，僅 on-demand，generation 5+）-
需要自己手動設定，包括 `limits`，否則 pool 會沒有上限地成長（第 9 章，第 9.7 節）。

## 快速檢查

```bash
check_result
```
