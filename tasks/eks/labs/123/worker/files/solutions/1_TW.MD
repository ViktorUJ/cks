[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 123 - 參考解答(Karpenter:NodePool、consolidation、StatefulSet)

所有指令都在 worker 機器上透過 SSH 執行。kubectl 已經為叢集設定好了
(kubeconfig 是機器啟動時透過 `aws eks update-kubeconfig` 組裝的)。

## 任務 1. Namespace `eks-123`

```bash
kubectl create namespace eks-123
```

## 任務 2. NodePool、EC2NodeClass、NodeClaim 的盤點

我們看看叢集中已經設定了哪些 pool:預設的 `default`(spot 與 on-demand)以及
新的 `stateful`(只有 on-demand,taint `dedicated=stateful`):

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== nodepools ==="
  kubectl get nodepools -o wide
  echo "=== ec2nodeclasses ==="
  kubectl get ec2nodeclasses
  echo "=== nodeclaims ==="
  kubectl get nodeclaims
} > /var/work/tests/artifacts/2/inventory.txt

cat /var/work/tests/artifacts/2/inventory.txt
```

輸出中應該有名稱為 `default` 和 `stateful` 的行 - 這是兩個獨立的 NodePool,
各自擁有自己的 `EC2NodeClass`(第 12.2-12.3 章)。

## 任務 3. `stateful` pool 上的 StatefulSet `db`

`stateful` pool 被 taint `dedicated=stateful:NoSchedule` 封鎖,所以 pod 需要
一個 toleration。這個實驗的目的不要求 volume - 重點在 disruption,不在 EBS
(StatefulSet 帶自己 PVC 的 volume 會在第 23 章討論):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-123
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: stateful
          effect: NoSchedule
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          resources:
            requests:
              cpu: "250m"
              memory: "128Mi"
EOF

kubectl rollout status statefulset/db -n eks-123
```

檢查所有副本是否都落在 `stateful` pool 上(node 標籤 `work_type=stateful`):

```bash
kubectl get po -n eks-123 -l app=db -o wide
kubectl get nodes -L work_type
```

## 任務 4. PodDisruptionBudget `db-pdb`

`maxUnavailable: 1` 是阻止自願驅逐的主要機制。Karpenter 透過 Eviction API
進行排空,所以 PDB 不會允許同時驅逐超過一個副本:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: db-pdb
  namespace: eks-123
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: db
EOF

kubectl get pdb db-pdb -n eks-123
```

## 任務 5. 症狀:沒有驅逐權限的 PDB 阻擋了 consolidation

`stateful` pool 的 node 已經利用率不足:三個副本各用 `250m`,分布在兩個
`m6g.medium` node 上,而 Karpenter 帶著 `consolidateAfter: 30s`,一直嘗試對
它們進行 consolidation。不需要強制施加負載 - 只需要看看是什麼阻擋了
consolidation。

重要:在 `maxUnavailable: 1` 的情況下,PDB 並不會阻擋 consolidation。它每次
允許一個驅逐(`ALLOWED DISRUPTIONS=1`),Karpenter 一次排空一個副本,並平靜
地刪除該 node。只有當 PDB 完全不允許任何驅逐時,才會發生阻擋。我們把保護收緊
到完全鎖定 - 在三個副本的情況下設為 `minAvailable: 3`:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"maxUnavailable":null,"minAvailable":3}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` 欄位現在顯示 `0`。等 1-2 分鐘後,pool 的 node 上會出現
阻擋事件。請注意:這不是 `Unconsolidatable`,而是一個獨立的
`DisruptionBlocked`:

```bash
for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $n ==="
  kubectl describe node "$n" | grep -A2 DisruptionBlocked
done
```

預期的行:`Pdb prevents pod evictions (PodDisruptionBudget=[eks-123/db-pdb])`。
controller 本身的 log 在 `karpenter` namespace 中(不是在 `kube-system` -
那裡只有 addon,Karpenter 是以獨立的 release 部署在 Fargate profile 上的):

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i "disrupting node"
```

我們把觀察結果存到 artifact 中 - `get pdb` 的輸出加上實際的 node 事件:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "症狀:一個完全不允許任何驅逐的 PDB 阻擋了 consolidation。"
  echo "db-pdb 被收緊到 minAvailable=3,在有 3 個副本時 -> ALLOWED DISRUPTIONS=0。"
  kubectl get pdb db-pdb -n eks-123
  echo
  echo "=== stateful pool node 事件 ==="
  for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
    kubectl describe node "$n" | grep -E "DisruptionBlocked|Unconsolidatable" | sed "s|^|$n |"
  done
} > /var/work/tests/artifacts/5/consolidation.txt

cat /var/work/tests/artifacts/5/consolidation.txt
```

我們把 PDB 恢復到可用的狀態,否則任務 4 不會通過,而且 pool 的 node 永遠都
無法離開:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"minAvailable":null,"maxUnavailable":1}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` 再次變回 `1`。實務上的結論:`minAvailable` 等於副本
數量(或 `maxUnavailable: 0`)不僅會停止 consolidation,還會停止任何 drain -
也就是說,node 更新和叢集升級也會被停止(第 12.6 章,第 40 章)。

## 任務 6. 修復:針對性的 `do-not-disrupt`

正確保護一個 StatefulSet 需要三個部分的組合(第 12.7 章),不是一個涵蓋一切
的 annotation。PDB(任務 4)已經提供了按副本進行的驅逐。`stateful` pool 的
disruption budget(`eks_karpenter_stateful_vng/terragrunt.hcl` 中的
`nodes: 50%`)限制了速度,讓 Karpenter 不會一次動到 pool 裡的所有 node。第三
部分是 `do-not-disrupt`,只針對性地放在目前不能接受中斷的那個副本上(例如
`db-0` 持有 leadership 或正在進行長時間的操作),而不是放在整個 StatefulSet
上:

```bash
kubectl annotate pod db-0 -n eks-123 karpenter.sh/do-not-disrupt=true
kubectl get po db-0 db-1 db-2 -n eks-123 \
  -o custom-columns=NAME:.metadata.name,DO_NOT_DISRUPT:'.metadata.annotations.karpenter\.sh/do-not-disrupt'
```

`db-1` 和 `db-2` 不會得到這個 annotation - 否則保護就會變成全面性的,不僅會
阻擋 consolidation,還會阻擋 drift(AMI 更新),就像第 12.8 章描述的那樣。

要確認這個 annotation 真的有作用,可以透過和任務 5 中 PDB 一樣的機制來觀察 -
Karpenter 會在承載 `db-0` 的那個 node 上寫下一個獨立的事件:

```bash
NODE=$(kubectl get po db-0 -n eks-123 -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | grep -A1 'do-not-disrupt'
```

預期的行:`DisruptionBlocked ... Pod has "karpenter.sh/do-not-disrupt"
annotation (Pod=eks-123/db-0)`。也就是說,這個針對性的 annotation 只會停止
承載受保護副本的那一個 node 的 consolidation,而 Karpenter 仍然可以動到 pool
裡的其他 node。

把說明存到 artifact 中:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/fix.txt <<'EOF'
在 consolidation 期間,正確保護 StatefulSet db 的方法是三個獨立的部分,
不是一個涵蓋一切的 annotation:

1. PDB db-pdb (maxUnavailable: 1) - 按副本進行驅逐,quorum 永遠不會失去。
   正是這個值讓 ALLOWED DISRUPTIONS 保持為 1。全面鎖定(在有 3 個副本時
   minAvailable=3)會導致 ALLOWED DISRUPTIONS=0,以及 DisruptionBlocked
   "Pdb prevents pod evictions" 事件 - 永遠這樣,直到 PDB 本身被修正
   (任務 5)。
2. stateful pool 的 disruption budget (nodes: 50%) - 限制 Karpenter
   同時能動到 pool 中多少個 node,不讓整個 pool 一次全部 consolidation。
3. karpenter.sh/do-not-disrupt=true 針對性地放在 db-0 上 - 保護那個目前
   不能接受中斷的具體副本,不是整個 StatefulSet。

如果 do-not-disrupt 同時放在 db-0、db-1 和 db-2 上,那就不僅會阻擋
consolidation,還會阻擋 drift:當新的 AMI 出現時,stateful pool 的 node
將無法更新,CVE 債務將會累積(第 12.8 章)。所以這個 annotation 只會放在
一個副本上,並在關鍵操作完成後移除。
EOF

cat /var/work/tests/artifacts/6/fix.txt
```

## 快速檢查

```bash
check_result
```
