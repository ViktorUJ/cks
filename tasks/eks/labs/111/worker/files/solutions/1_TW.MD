[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 111 - 參考解答(spot 節點:diversification、中斷、graceful drain)

所有指令都在工作機上透過 SSH 執行。kubectl 已經配置好指向該集群(kubeconfig 是在
機器啟動時透過 `aws eks update-kubeconfig` 生成的)。

## 任務 1. Namespace `eks-111`

```bash
kubectl create namespace eks-111
```

## 任務 2. 在帶有 toleration 與 graceful shutdown 的 spot 資源池上部署 Deployment `spotapp`

資源池 `spot-lab` 被 taint `dedicated=spot-lab:NoSchedule` 封閉,因此 pod 必須帶上
對應的 toleration,否則 Karpenter 無法將它排到這個 NodePool 上。
`terminationGracePeriodSeconds: 60` 落在兩分鐘的 spot 中斷窗口之內,而帶有
`sleep 5` 的 `preStop` 則讓負載平衡器在容器停止前有時間把流量引走。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spotapp
  namespace: eks-111
spec:
  replicas: 4
  selector:
    matchLabels:
      app: spotapp
  template:
    metadata:
      labels:
        app: spotapp
    spec:
      terminationGracePeriodSeconds: 60
      tolerations:
        - key: "dedicated"
          value: "spot-lab"
          effect: "NoSchedule"
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "sleep 5"]
EOF

kubectl rollout status deployment/spotapp -n eks-111
```

檢查所有 4 個副本是否都落在 spot 節點上:

```bash
kubectl get po -n eks-111 -l app=spotapp -o wide
NODES=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[*].spec.nodeName}')
for n in $NODES; do
  kubectl get node "$n" -L karpenter.sh/capacity-type --no-headers
done
```

Karpenter 拉起一個新的 EC2 節點大約需要 60-90 秒,所以一開始 pod 可能會停留在
`Pending` 狀態。在繼續下一步之前,先等待 `rollout status` 完成。

## 任務 3. 產物:spot 節點與 NodePool 的 diversification

保存帶有 capacity type 標籤與 instance category 的節點快照,以及 NodePool
`spot-lab` 的 requirements,以確認廣泛的系列組合(diversification)。

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -L karpenter.sh/capacity-type -L karpenter.k8s.aws/instance-category \
  > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt

kubectl get nodepool spot-lab -o yaml \
  | grep -A5 'instance-category' > /var/work/tests/artifacts/3/nodepool.txt
cat /var/work/tests/artifacts/3/nodepool.txt
```

`nodes.txt` 中應該至少有一個 `capacity-type=spot` 的節點。`nodepool.txt` 中應該
存在三個 instance category `c`、`m`、`r` - 這正是 diversification 的要求:spot-lab
資源池並沒有被收窄到單一的 instance 系列。

## 任務 4. 針對 `spotapp` 的 PodDisruptionBudget

`minAvailable: 3`(共 4 個副本)可以防止過度的 voluntary eviction:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spotapp-pdb
  namespace: eks-111
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: spotapp
EOF

kubectl get pdb spotapp-pdb -n eks-111 -o yaml
```

## 任務 5. 症狀:drain 被 PDB 阻擋,但這不能保護免受 AWS 的 spot 回收

找出一個帶有至少一個 `spotapp` pod 的節點,對它執行 cordon,然後嘗試 drain。在 4 個
副本、`minAvailable: 3` 的情況下,PDB 一次最多只允許驅逐一個副本
(`disruptionsAllowed` 不超過 1) - drain 無法超過這一個副本繼續往下走。

```bash
NODE=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[0].spec.nodeName}')
kubectl cordon "$NODE"
kubectl get pdb spotapp-pdb -n eks-111 -o jsonpath='{.status.disruptionsAllowed}'
echo

# 嘗試被驅逐的對象,而不對整個節點做真正的 drain
kubectl drain "$NODE" --ignore-daemonsets --dry-run=client
```

把症狀以及 PDB 職責邊界的說明記錄到產物中:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/drain.txt <<'EOF'
節點已被 cordon,drain 試圖透過 eviction API 驅逐 spotapp 的 pod。PDB
spotapp-pdb 的 minAvailable: 3 不允許一次驅逐超過一個副本(在 4 個副本的情況下
disruptionsAllowed <= 1):一旦嘗試違反這個 budget,eviction 就會被拒絕,drain
無法超過這一個副本繼續往下走。

重要的邊界:PDB 只保護 voluntary eviction - kubectl drain、節點升級、
Karpenter 的 consolidation。它不能保護免受 AWS 對 spot 的強制回收:如果 AWS 在
兩分鐘通知期滿後真的收回了這個 instance,上面的 pod 會不受 PDB 影響直接終止,因為
這並不是 Kubernetes 的 voluntary 行為,而是 instance 本身被停止。
EOF
cat /var/work/tests/artifacts/5/drain.txt

kubectl uncordon "$NODE"
```

## 任務 6. 檢查 Karpenter 的中斷處理

Karpenter 透過中斷佇列(`interruptionQueue`,在模組 `eks_v2_karpenter` 中配置,
與本實驗無關)自行處理 spot 中斷。我們透過控制器日誌來確認這個機制 - worker 可能
沒有 `aws sqs list-queues` 的權限,因此使用 `kubectl logs`:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i interrupt > /var/work/tests/artifacts/6/interruption.txt

# 如果目前還沒有中斷事件,就記錄機制本身已經配置好這個事實:
if [[ ! -s /var/work/tests/artifacts/6/interruption.txt ]]; then
  echo "no interruption events yet, but Karpenter interruption handling is configured via interruptionQueue" \
    > /var/work/tests/artifacts/6/interruption.txt
fi
cat /var/work/tests/artifacts/6/interruption.txt
```

## 快速檢查

```bash
check_result
```
