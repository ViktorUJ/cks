[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 131 - 參考解答（PDB 阻塞 drain、topology spread、matchLabelKeys）

所有命令都在工作機（worker）上透過 SSH 執行。kubectl 已經配置好指向集群（kubeconfig 是
機器啟動時透過 `aws eks update-kubeconfig` 建立的）。

## 任務 1. Namespace `eks-131`

```bash
kubectl create namespace eks-131
```

## 任務 2. 帶 topology spread 和 matchLabelKeys 的 Deployment `web`

本實驗的集群運行在兩個可用區（`eu-central-1a` 和 `eu-central-1b`），每個區都有私有子網
`eks1`/`eks2`。這足以讓 Karpenter 把節點分散到兩個可用區，並讓
`topologySpreadConstraints` 把 pod 分散到這些節點上。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-131
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
          matchLabelKeys:
            - pod-template-hash
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
EOF

kubectl rollout status deployment/web -n eks-131
```

檢查就緒情況及在各可用區的分散：

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

三個 pod 的 `NODE` 列中至少應出現兩個不同節點，而這些節點的
`topology.kubernetes.io/zone` 值應不同。`matchLabelKeys: [pod-template-hash]` 目前還不
會影響這第一次部署（只有一個版本），它會在任務 6 中發揮作用。

## 任務 3. 症狀：過於嚴格的 PDB 阻塞 drain

我們創建一個要求全部 3 個副本都可用的 PDB - 預算不允許驅逐任何一個 pod：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: eks-131
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
EOF
```

取一個運行著 `web` 副本的節點，嘗試將其排空：

```bash
NODE=$(kubectl get pod -n eks-131 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node: $NODE"

mkdir -p /var/work/tests/artifacts/3
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s \
  > /var/work/tests/artifacts/3/drain_blocked.txt 2>&1
echo "drain exit code: $?"
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

命令失敗：`kubectl drain` 嘗試對 `web` pod 調用 eviction API，但 API 因預算被違反而返回
`429`，而在 `--timeout=60s` 之後 drain 以 `global timeout reached` 錯誤結束。原因是 PDB
`web-pdb` 的 `minAvailable: 3` 要求 3 個可用副本，而現在恰好只有 3 個，於是預算永遠不允
許驅逐任何一個：驅逐永遠無法推進，drain 會一直卡住，直到預算被放寬。

把說明加到同一個產物中：

```bash
cat >> /var/work/tests/artifacts/3/drain_blocked.txt <<'EOF'

說明：PDB web-pdb 設置了 minAvailable: 3，等於 Deployment web 的副本數。預算不允許驅逐
任何一個 pod，因此 eviction API 返回 429，kubectl drain 就會卡住/超時 - 這是 PDB 過於
嚴格的症狀，而不是集群錯誤。
EOF
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

## 任務 4. 修復：放寬 PDB 並重試 drain

先把節點恢復到服務中（drain 已經把它 cordon 了）：

```bash
kubectl uncordon "$NODE"
```

放寬預算：現在可以驅逐三個副本中的一個（`minAvailable: 2`）：

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge -p '{"spec":{"minAvailable":2}}'
kubectl get pdb web-pdb -n eks-131
```

在同一節點上重試 drain - 現在預算允許驅逐一個 pod，drain 成功了：

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s \
  > /var/work/tests/artifacts/4/drain_ok.txt 2>&1
echo "drain exit code: $?" >> /var/work/tests/artifacts/4/drain_ok.txt

echo "--- pdb status after drain ---" >> /var/work/tests/artifacts/4/drain_ok.txt
kubectl get pdb web-pdb -n eks-131 >> /var/work/tests/artifacts/4/drain_ok.txt
cat /var/work/tests/artifacts/4/drain_ok.txt
```

把節點恢復到服務中，等待全部 3 個副本再次就緒（替代副本落在了另一個節點上）：

```bash
kubectl uncordon "$NODE"
kubectl rollout status deployment/web -n eks-131
```

## 任務 5. unhealthyPodEvictionPolicy: AlwaysAllow

默認情況下 PDB 使用 `IfHealthyBudget` 策略：只有在預算本來就不會被違反的情況下，才能驅逐
不健康（非 `Ready`）的 pod。如果應用程式故障、pod 卡在 `CrashLoopBackOff` 中，這個 pod
本身就會阻塞預算的計算，並可能永久阻止 drain。`AlwaysAllow` 解除了這個阻塞：不健康的 pod
永遠可以被驅逐，健康的 pod 仍受預算保護。

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge \
  -p '{"spec":{"unhealthyPodEvictionPolicy":"AlwaysAllow"}}'

kubectl get pdb web-pdb -n eks-131 -o jsonpath='{.spec.unhealthyPodEvictionPolicy}'
echo
```

把說明保存到產物中：

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/unhealthy_policy.txt <<'EOF'
unhealthyPodEvictionPolicy: AlwaysAllow 已加到 web-pdb。

默認情況下（IfHealthyBudget），只有當 currentHealthy 不會低於 desiredHealthy 時，不健康
的 pod 才會被驅逐，因此處於 CrashLoopBackOff 的 pod 會把自己算作預算的一部分，即使應用程
式已經不工作了，也可能永久阻塞 drain。

AlwaysAllow 允許無視預算驅逐不健康的 pod：卡在 CrashLoopBackOff 中的故障 pod 不再拖住
drain，而健康的副本仍受 PDB 保護。
EOF
cat /var/work/tests/artifacts/5/unhealthy_policy.txt
```

## 任務 6. 滾動更新：matchLabelKeys 讓舊 pod 不再干擾分佈

我們更新 Deployment，使其出現新版本（新的 `pod-template-hash`）：加入一個環境變數。舊 pod
和新 pod 共享標籤 `app: web`，但 `topologySpreadConstraints` 中的 `matchLabelKeys:
[pod-template-hash]` 讓 skew 只在自己版本內部計算，因此新 pod 不會被舊副本擋住。

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl set env deployment/web -n eks-131 RELEASE=v2

kubectl rollout status deployment/web -n eks-131 --timeout=180s \
  | tee /var/work/tests/artifacts/6/rollout.txt
```

檢查是否有卡住的 `Pending` pod，並確認更新確實已生效：

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get deploy web -n eks-131 \
  -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}'
echo
```

沒有 `matchLabelKeys: [pod-template-hash]` 時，舊 pod 和新 pod 都會參與 skew 的計算 -
它們共享標籤 `app: web`。有了它，調度器會給選擇器加上版本標籤，只在自己版本內計算分佈。

一個公道的說明，值得自己驗證而非盡信。在這個測試環境中，即使不用 `matchLabelKeys`
rollout 也能成功 - 經實驗驗證：第二個 Deployment 有相同的拓撲但沒有這個字段，配置
`maxUnavailable: 0` 和 `maxSurge: 1`，在相同的時間內完成了更新，`Pending` 持續不到五秒，
且是調度器普通的等待，而不是 skew 造成的阻塞。原因很簡單：三個副本分佈在兩個可用區得到
2 加 1 的分佈，多出的那個 pod 總能落到 pod 較少的可用區，而如果節點沒有空間，Karpenter
會再拉起一個節點。

差異真正顯現的地方：靜態機群沒有備用容量、可用區超過兩個、且舊版本分佈不均勻。這時同時
按兩個版本計算的 skew 不會給新 pod 留下任何允許的可用區，它就要等一個舊副本離開 - 在大
機群上這會變成緩慢的滾動更新，伴隨令人困惑的 `Pending`。因此 `matchLabelKeys` 要提前設
置好，而不是事後補救。現在真正檢查的結果是：新版本仍在 `maxSkew: 1` 範圍內分散於各可用
區：

```bash
HASH=$(kubectl get po -n eks-131 -l app=web \
  -o jsonpath='{.items[0].metadata.labels.pod-template-hash}')
for n in $(kubectl get po -n eks-131 -l app=web,pod-template-hash="$HASH" \
    -o jsonpath='{.items[*].spec.nodeName}'); do
  kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}'
done | sort | uniq -c
```

## 快速檢查

```bash
check_result
```
