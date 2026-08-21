[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 106 - 參考解答(EBS CSI: gp3、AZ 綁定、擴容、快照)

所有命令都在工作機(worker)上透過 SSH 執行。kubectl 已經配置好指向集群。驅動程式
`aws-ebs-csi-driver`(provisioner `ebs.csi.aws.com`)已經以 managed addon 的形式安裝,並
透過 IRSA 配置好角色(組件 `eks_addon_ebs_irsa`) - 不需要重新創建這個角色。

## 任務 1。Namespace `eks-106`

```bash
kubectl create namespace eks-106
```

## 任務 2。StorageClass `gp3-immediate`(故障配置)

刻意選用 `volumeBindingMode: Immediate` - 正是它會讓卷落在隨機的區域:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-immediate
provisioner: ebs.csi.aws.com
volumeBindingMode: Immediate
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF
```

## 任務 3。建立在 `gp3-immediate` 上的 StatefulSet `db`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-106
spec:
  serviceName: db
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3-immediate
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl get pvc -n eks-106
kubectl get po db-0 -n eks-106 -o wide
```

實驗集群建立在兩個 AZ 中(`eu-central-1a` 和 `eu-central-1b`)。在 `Immediate` 模式下,
驅動程式會在 PVC 出現後立即創建卷,而不會等待規劃器把 Pod 排到哪個節點,因此卷所在的
區域和 Karpenter 實際建立節點的區域是互相獨立選擇的。在只有兩個 AZ 的情況下,
`volume node affinity conflict` 確實會發生,但並不是每次執行都能保證重現:卷有可能恰好
落在已經有合適節點的那個區域。正因為如此,任務 4 中的診斷無論結果如何都是必須完成的。

## 任務 4。診斷:Immediate 症狀與 AZ 綁定的對比

```bash
mkdir -p /var/work/tests/artifacts/4

kubectl describe pod db-0 -n eks-106 | sed -n '/Events/,$p' \
  > /var/work/tests/artifacts/4/describe.txt

PV=$(kubectl get pvc data-db-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/4/pv.yaml
grep -A6 nodeAffinity /var/work/tests/artifacts/4/pv.yaml
```

查看 Pod 實際落在哪裡,以及卷所在區域是否與節點所在區域一致:

```bash
PHASE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.status.phase}')
NODE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "phase=$PHASE node=$NODE pv_zone=$PV_ZONE"
```

將說明保存為產物。這段話在兩種情況下都要能成立 - 無論 Pod 卡在 `Pending`,還是恰好
運氣好變成 `Running`:

```bash
cat > /var/work/tests/artifacts/4/diagnosis.txt <<'EOF'
StorageClass gp3-immediate 使用 volumeBindingMode: Immediate。這意味著 CSI 驅動程式
ebs.csi.aws.com 會在 PVC 出現之後立即創建 EBS 卷,在規劃器還沒有為 Pod 選定節點之前。
卷所在的區域被固定在 PV 的 spec.nodeAffinity.required.nodeSelectorTerms[].matchExpressions[]
中,鍵為 topology.ebs.csi.aws.com/zone,而規劃器必須遵守這個綁定。

如果 Pod db-0 處於 Pending,kubectl describe pod 會顯示事件
"0/N nodes are available: N node(s) had volume node affinity conflict" - 卷創建在了一
個沒有合適節點的區域。

如果 Pod db-0 處於 Running,並不代表配置是正確的:集群一共只有兩個 AZ
(eu-central-1a、eu-central-1b),在 Immediate 模式下,卷恰好落在了已經有節點的那個區
域,純屬運氣。在另一次執行中,或是 Karpenter 進行 consolidation 之後,或是遷移到更多
AZ 的情況下,同一個 StorageClass 還會再次出現 volume node affinity conflict。只有
WaitForFirstConsumer 才能保證正確運作,因為在它的模式下卷所在的區域永遠等於已經選定的
節點所在的區域 - 這正是任務 5 的內容。
EOF
cat /var/work/tests/artifacts/4/diagnosis.txt
```

## 任務 5。修復:帶有 `WaitForFirstConsumer` 的 StorageClass `gp3`

PVC 只會綁定一次自己的 StorageClass,已存在的 PVC 無法更換類別,所以修復的方式不是對
`gp3-immediate` 打補丁,而是用新的類別和新的 StatefulSet:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  encrypted: "true"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-fixed
  namespace: eks-106
spec:
  serviceName: db-fixed
  replicas: 1
  selector:
    matchLabels:
      app: db-fixed
  template:
    metadata:
      labels:
        app: db-fixed
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      storageClassName: gp3
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 5Gi
EOF

kubectl rollout status statefulset/db-fixed -n eks-106
```

在 `WaitForFirstConsumer` 模式下,卷的供應會被推遲,直到規劃器為 `db-fixed-0` 選定節
點。只有到那時,驅動程式才會在該節點所在的區域創建卷,`nodeAffinity` 衝突在結構上就變
得不可能發生。驗證卷所在的區域與節點所在的區域是否一致:

```bash
NODE=$(kubectl get po db-fixed-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
PV=$(kubectl get pvc data-db-fixed-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "node_zone=$NODE_ZONE pv_zone=$PV_ZONE"
```

`node_zone` 和 `pv_zone` 的值應該一致 - 這是配置正確而非碰巧成功的標誌。另外,如果需
要從卷的供應範圍中排除某個特定的 AZ,也可以透過 StorageClass 中的 `allowedTopologies`
(鍵為 `topology.ebs.csi.aws.com/zone`)明確限制區域範圍。

## 任務 6。將卷 `data-db-fixed-0` 從 5Gi 擴容到 10Gi

`gp3` 中的 `allowVolumeExpansion: true` 允許在不重建 Pod 的情況下進行線上擴容:

```bash
kubectl patch pvc data-db-fixed-0 -n eks-106 \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# 等待 CSI 驅動程式完成卷與檔案系統的修改
until [[ "$(kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}')" == "10Gi" ]]; do
  sleep 5
done

kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}'
echo
```

不能縮小卷 - 只能擴大,而且擴容頻率不能超過 EBS 修改次數的限制。

## 任務 7。卷的快照與還原(best effort)

快照透過三個物件協作:`VolumeSnapshotClass`、`VolumeSnapshot`,以及自動創建的
`VolumeSnapshotContent`。集群中的 snapshot-controller 和 CRD 已經以 managed addon
`snapshot-controller`(組件 `eks_addons`)的形式安裝好了:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapclass
driver: ebs.csi.aws.com
deletionPolicy: Delete
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: db-snap
  namespace: eks-106
spec:
  volumeSnapshotClassName: ebs-snapclass
  source:
    persistentVolumeClaimName: data-db-fixed-0
EOF

kubectl get volumesnapshot db-snap -n eks-106
```

等待快照變為就緒狀態(`readyToUse: true`),然後將它還原到一個新的 PVC 中。EBS 快照是
一個區域性(regional)物件,但從它還原出來的卷仍然是分區(zonal)的,所以這裡同樣需要
帶有 `WaitForFirstConsumer` 的類別:

```bash
kubectl wait --for=jsonpath='{.status.readyToUse}'=true \
  volumesnapshot/db-snap -n eks-106 --timeout=180s

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-restored
  namespace: eks-106
spec:
  storageClassName: gp3
  accessModes: ["ReadWriteOnce"]
  dataSource:
    kind: VolumeSnapshot
    name: db-snap
    apiGroup: snapshot.storage.k8s.io
  resources:
    requests:
      storage: 10Gi
EOF

kubectl get pvc data-restored -n eks-106
```

`data-restored` 會停留在 `Pending`,直到有 Pod 使用它(類別 `gp3` 是
`WaitForFirstConsumer`),這是預期行為:還原後的卷的供應同樣會被推遲到排程階段。如果集
群中因為某種原因沒有 snapshot-controller 或 CRD,這個任務本身不會阻塞整個實驗其餘的部
分 - 這是一個獨立的、非必須的驗證步驟。

## 快速檢查

```bash
check_result
```
