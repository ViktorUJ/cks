[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 118 - 參考解答（GitOps：Argo CD、drift 與 self-heal、sync waves）

所有指令都在 worker 機器上透過 SSH 執行。kubectl 已經針對這個 cluster 設定好了
（kubeconfig 是機器開機時透過 `aws eks update-kubeconfig` 組裝出來的）。

## 任務 1. 透過 Helm 安裝 Argo CD

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd

kubectl rollout status deployment/argocd-server -n argocd
```

檢查 server 有沒有啟動起來：

```bash
kubectl get deploy argocd-server -n argocd
kubectl get pods -n argocd
```

## 任務 2. Namespace `eks-118` 和 Application 物件

```bash
kubectl create namespace eks-118
```

Application 把一個 Git 來源（課程本身的 repository，branch `AG-155`，路徑
`tasks/eks/labs/118/gitops-demo`）和目標 cluster、namespace `eks-118` 連結起
來。`selfHeal: true` 會復原手動修改，`prune: true` 會把從 Git 中移除的資源從
cluster 中刪除：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ViktorUJ/cks.git
    targetRevision: AG-155
    path: tasks/eks/labs/118/gitops-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: eks-118
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF
```

等待 Application 到達 `Synced` 和 `Healthy`：

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}'
echo
```

這兩個指令最後應該分別回傳 `Synced` 和 `Healthy`（Argo CD 會自動查詢 Git 並套用
manifest，auto-sync 預設是啟用的）。

## 任務 3. 確認物件確實被套用了

```bash
kubectl get deployment demo-app -n eks-118
kubectl get configmap demo-config -n eks-118 -o yaml
kubectl rollout status deployment/demo-app -n eks-118
```

Deployment `demo-app`（image `viktoruj/ping_pong:latest`，2 個 replica）和
ConfigMap `demo-config` 是透過 Argo CD 從 Git 而來的，不是學員手動
`kubectl apply` 的結果。

## 任務 4. Drift 和 self-heal

一個只有在真實 cluster 上才能看到的重要細節：當 `selfHeal` 啟用時，controller
會在幾秒內把 drift 復原，用肉眼幾乎不可能捕捉到 `OutOfSync`（手動的
`kubectl scale` 甚至在第一次 `kubectl get application` 之前就被復原了）。因此
drift 分兩步展示：先關閉自我修復，捕捉 `OutOfSync`，然後再打開自我修復，觀察
復原。

步驟 1. 只關閉 `selfHeal`，`prune` 保持啟用：

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false,"prune":true}}}}'
```

步驟 2. 在不經過 Git 的情況下破壞即時狀態，並記錄 drift：

```bash
kubectl scale deployment demo-app -n eks-118 --replicas=5

for i in $(seq 1 20); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  [[ "$status" == "OutOfSync" ]] && break
  sleep 3
done

mkdir -p /var/work/tests/artifacts/4
{
  echo "=== selfHeal=false 時的 drift（手動 kubectl scale --replicas=5）==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} > /var/work/tests/artifacts/4/drift.txt
```

沒有 self-heal 時，Application 會保持 `OutOfSync`：auto-sync 會對 Git 的
變化做出反應，而在 cluster 內部產生的差異正是由 `selfHeal` 來修復的。

步驟 3. 重新啟用 `selfHeal`，觀察自動復原到 Git 中的狀態：

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'

for i in $(seq 1 40); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  replicas=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.spec.replicas}')
  [[ "$status" == "Synced" ]] && [[ "$replicas" == "2" ]] && break
  sleep 3
done

{
  echo "=== 重新啟用 selfHeal 後：復原到 Git 中的狀態 ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} >> /var/work/tests/artifacts/4/drift.txt

cat /var/work/tests/artifacts/4/drift.txt
```

檔案中同時包含 `OutOfSync`（沒有自我修復時的 drift）和 `Synced`（self-heal
把 Git 中的狀態帶回來了）。最後 `replicas` 又變成 `2`。

## 任務 5. Sync waves：套用的順序

`gitops-demo/configmap.yaml` 上有 annotation
`argocd.argoproj.io/sync-wave: "0"`，而 `gitops-demo/deployment.yaml` 上是
`argocd.argoproj.io/sync-wave: "1"`。較小的 wave 編號會先被套用，所以 ConfigMap
一定會在 Deployment 之前進入 cluster（如果 Deployment 透過 `envFrom` 從
ConfigMap 讀取值，這一點就很重要）：

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
kubectl get deployment demo-app -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
```

確認即使處於不同的 wave，兩個物件最後都已經同步：

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.resources}' | head -c 400
```

## 任務 6. prune 會刪除什麼、不會刪除什麼：資源的所有權

`prune: true` 從任務 2 開始就已經啟用了。我們在 `eks-118` 中手動建立一個
`gitops-demo/` 裡沒有的 ConfigMap - 一個普通的手動物件，就像有人在 Git 之外
建立了它：

```bash
kubectl create configmap manual-extra -n eks-118 --from-literal=note=manual

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

sleep 30
kubectl get configmap manual-extra -n eks-118
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'; echo
```

意外的結果：`prune=true` 已啟用，但 `manual-extra` **沒有被刪除**，而
Application 依然是 `Synced`。原因在於所有權模型：Argo CD 只管理那些被標記為
屬於該 application 的物件。在 Argo CD 3.x 中，這就是 annotation
`argocd.argoproj.io/tracking-id` - 看看從 Git 來的物件是怎麼被標記的：

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'; echo
# demo-app:/ConfigMap:eks-118/demo-config
```

手動建立的物件沒有這個標記，對 Argo CD 來說它是陌生的（orphaned），不會落入
prune 的範圍。記錄這個觀察結果：

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== 沒有 tracking annotation 時，prune 不會動這個物件 ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "sync: $(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')"
} > /var/work/tests/artifacts/6/prune.txt
```

現在把這個 ConfigMap 標記為屬於這個 application。值的格式是
`<app>:<group>/<Kind>:<namespace>/<name>`，core 資源的 group 是空的：

```bash
kubectl annotate configmap manual-extra -n eks-118 \
  'argocd.argoproj.io/tracking-id=demo-app:/ConfigMap:eks-118/manual-extra' --overwrite

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

for i in $(seq 1 20); do
  kubectl get configmap manual-extra -n eks-118 >/dev/null 2>&1 || break
  sleep 5
done

kubectl get configmap manual-extra -n eks-118 2>&1
```

現在這個物件被這個 application 追蹤了，它不在 Git 中 - 所以 prune 會把它刪除。
同時 `demo-config` 和 `demo-app` 保持原樣，因為它們在 `gitops-demo/` 中有描述：

```bash
{
  echo "=== 加上 tracking annotation 之後，prune 刪除了這個物件 ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 2>&1 | tail -n1)"
  echo "demo-config: $(kubectl get configmap demo-config -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "demo-app: $(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.metadata.name}')"
  echo
  echo "prune 只會移除被 application 追蹤（tracked）且在 Git 中缺失的資源。"
  echo "沒有 tracking annotation 的手動物件對 Argo CD 來說是陌生的"
  echo "（orphaned），不會落入 prune 的範圍 - 這就是第一次觀察到的結果。"
  echo "demo-config 和 demo-app 保持原樣，因為它們在 gitops-demo/ 中有描述，"
  echo "Argo CD 仍然在持續同步它們。"
} >> /var/work/tests/artifacts/6/prune.txt

cat /var/work/tests/artifacts/6/prune.txt
```

## 任務 7. 診斷：sync status 和 health status - 兩個不同的軸

停用 auto-sync（連同 self-heal 一起，因為它們在同一個區塊裡），這樣就能平靜地
觸發症狀，而不會馬上被復原：

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

直接在 cluster 中破壞容器的 readinessProbe。注意：訓練用 image `ping_pong`
對任何路徑都會回應 `200`，所以指向「不存在的 URL」的 probe 會順利通過，不會
產生任何症狀。改把 probe 指向已關閉的 port `9999` - 那裡沒有東西在監聽：

```bash
kubectl patch deployment demo-app -n eks-118 --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe","value":{
    "httpGet": {"path": "/healthz", "port": 9999},
    "initialDelaySeconds": 2,
    "periodSeconds": 3,
    "failureThreshold": 2
  }}
]'
```

等待並記錄狀態。Sync 和 health 是兩個獨立的軸：sync 反映的是 Git 和即時狀態之間
的差異，health 是資源真正的健康狀況（pod 的就緒狀態等等）：

```bash
sleep 30
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== 手動修改 readinessProbe 之後觀察到的狀態 ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  echo
  echo "=== 說明：sync status 和 health status 是不同的軸 ==="
  echo "Sync status（Synced/OutOfSync）比較的是物件的即時狀態和 Git 中記錄的內容："
  echo "一致就是 Synced，不一致就是 OutOfSync。"
  echo "Health status（Healthy/Progressing/Degraded/Missing）是資源現在真正的"
  echo "健康狀況：pod 是否就緒，readiness/liveness probe 是否通過。"
  echo "因為 probe 指向已關閉的 port，新的 demo-app pod 無法通過 readiness，所以"
  echo "health 變成 Progressing（progressDeadlineSeconds 過期後會變成"
  echo "Degraded），而 sync 仍然保持 Synced。原因：readinessProbe 這個欄位沒有"
  echo "在 Git manifest 中描述，手動加上的欄位不會被算進差異裡；而 replicas 在"
  echo "Git 中是有的，所以任務 4 中手動修改它才會產生 OutOfSync。"
  echo "這證明了這兩個軸是各自獨立計算的：可以同時處於 Synced 和"
  echo "Degraded/Progressing，就像可以同時處於 OutOfSync 和 Healthy 一樣。"
} > /var/work/tests/artifacts/7/health.txt

cat /var/work/tests/artifacts/7/health.txt
```

重新啟用 auto-sync 和 self-heal：

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'
```

一個重要的觀察：self-heal **不會**修復這個故障。因為對 Argo CD 來說，跟 Git
之間沒有差異（`sync=Synced`），所以沒有什麼需要修復 - 同時 `health` 誠實地
顯示 `Progressing`，然後變成 `Degraded`。實際的結論是：`Synced` 不代表 cluster
和 Git 逐位元組完全一致；manifest 中不存在的欄位仍然是操作者的責任。所以我們
手動移除這個 probe：

```bash
kubectl patch deployment demo-app -n eks-118 --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'

for i in $(seq 1 20); do
  health=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}')
  ready=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.status.readyReplicas}')
  [[ "$health" == "Healthy" ]] && [[ "$ready" == "2" ]] && break
  sleep 5
done

kubectl get application demo-app -n argocd \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
echo
```

## 快速檢查

```bash
check_result
```
