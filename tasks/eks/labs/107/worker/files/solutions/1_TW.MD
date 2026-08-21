[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 107 - 參考解答(EFS CSI:跨 AZ 的 ReadWriteMany)

所有命令都在 worker 機器上透過 SSH 執行。kubectl 已經設定好指向叢集。`aws-efs-csi-driver`
driver(provisioner `efs.csi.aws.com`)已經以 managed addon 的形式安裝好,並帶有透過 IRSA
取得的 role(元件 `eks_addon_efs_irsa`),EFS 檔案系統以及每個 AZ 中的 mount target 也已經
由 terraform 建立好 - 不需要再重新建立它們。

## 任務 1. Namespace `eks-107`

```bash
kubectl create namespace eks-107
```

## 任務 2. 指向真實 `fileSystemId` 的 StorageClass `efs-sc`

檔案系統已經提前由 terraform 建立好,driver 只是在它上面工作。我們透過 AWS CLI 找到它的 ID
(標籤 `Name` 是由 lab 的 `prefix` 組成的):

```bash
FS_ID=$(aws efs describe-file-systems --region eu-central-1 \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='eks-task107-efs']].FileSystemId" \
  --output text)
echo "$FS_ID"

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${FS_ID}
  directoryPerms: "755"
  uid: "1000"
  gid: "1000"
  basePath: "/dynamic"
mountOptions: ["tls"]
EOF
```

`provisioningMode: efs-ap` 代表動態佈建:driver 會為每個 PVC 在這個檔案系統內部建立一個
獨立的 access point,而不是把整個檔案系統交出去。

## 任務 3. PVC `shared-data`(`ReadWriteMany`,`5Gi`)

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: shared-data
  namespace: eks-107
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: efs-sc
  resources:
    requests:
      storage: 5Gi
EOF

kubectl get pvc shared-data -n eks-107
```

EFS 是跨區域的系統,所以無論之後 pod 落在哪個區域,PVC 都會轉為 `Bound` 狀態:mount target
在它被建立的任何一個 AZ 中都可以被存取到。

## 任務 4. Deployment `writer`(3 個 replica,不同 AZ,共用 PVC)

針對 key `topology.kubernetes.io/zone` 的 `topologySpreadConstraints` 讓 scheduler 把
replica 分散到不同的區域:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: writer
  namespace: eks-107
spec:
  replicas: 3
  selector:
    matchLabels:
      app: writer
  template:
    metadata:
      labels:
        app: writer
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: topology.kubernetes.io/zone
        whenUnsatisfiable: DoNotSchedule
        labelSelector:
          matchLabels:
            app: writer
      containers:
      - name: app
        image: viktoruj/ping_pong:alpine
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: shared-data
EOF

kubectl rollout status deployment/writer -n eks-107
kubectl get po -n eks-107 -l app=writer -o wide
```

檢查 replica 是否分布在不同的 AZ 上:

```bash
kubectl get po -n eks-107 -l app=writer \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName' --no-headers | \
  while read -r pod node; do
    zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
    echo "$pod  node=$node  zone=$zone"
  done
```

所有 3 個 replica 同時處於 `Running` 狀態,並掛載同一個 PVC `shared-data`,儘管它們位於
不同的 AZ。用 EBS 的話這是不可能的(`ReadWriteOnce`,錯誤 `Multi-Attach error`),因為
EBS 是區域性的區塊 volume,而 EFS 是跨區域的 NFS 系統,每個區域都有自己的 mount target。

## 任務 5. 共用存取:從一個 replica 寫入,從另一個 replica 讀取

```bash
PODS=($(kubectl get po -n eks-107 -l app=writer -o jsonpath='{.items[*].metadata.name}'))
WRITER_POD=${PODS[0]}
READER_POD=${PODS[1]}

kubectl exec -n eks-107 "$WRITER_POD" -- sh -c \
  'echo "efs-rwx-test from $(hostname)" >> /data/shared.txt'

mkdir -p /var/work/tests/artifacts/5
kubectl exec -n eks-107 "$READER_POD" -- cat /data/shared.txt \
  > /var/work/tests/artifacts/5/readback.txt
cat /var/work/tests/artifacts/5/readback.txt
```

由 pod `$WRITER_POD` 在某個 AZ 中寫入的那一行,被 pod `$READER_POD` 在另一個 AZ 中讀取到
了 - 這確認了它真的是一個透過 NFS 共用的網路 volume,而不是節點磁碟上的本機副本。

## 任務 6. 檢查是否缺少區域性的 `nodeAffinity`

```bash
mkdir -p /var/work/tests/artifacts/6

PV=$(kubectl get pvc shared-data -n eks-107 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/6/pv.yaml
grep -A3 nodeAffinity /var/work/tests/artifacts/6/pv.yaml
echo "exit code: $?"

cat > /var/work/tests/artifacts/6/explanation.txt <<'EOF'
efs.csi.aws.com 建立的 PV 沒有 spec.nodeAffinity 區塊(與 EBS 不同,第 23 章中,
nodeAffinity 透過 key topology.ebs.csi.aws.com/zone 把某個特定 AZ 固定下來)。原因在於
EFS 是一個跨區域的檔案系統,每個 AZ 都有 mount target,所以使用這個 volume 的 pod 可以
在叢集的任何其他區域被重建,並繼續透過新區域的 mount target 看到同一份資料。scheduler
不需要因為這個 volume 就把 pod 固定到某個特定節點或區域,而 EBS 就需要這麼做。
EOF
cat /var/work/tests/artifacts/6/explanation.txt
```

命令 `grep -A3 nodeAffinity` 什麼都找不到(輸出為空,exit code `1`) - 這就是該區塊不存在
的確認。可以與 lab 106(EBS)的 `pv.yaml` 對比,那裡的
`spec.nodeAffinity.required.nodeSelectorTerms` 會嚴格地把 volume 的區域固定下來。

## 任務 7. 診斷:mount target 的 SG 與 2049 port(僅讀取)

實際破壞基礎架構的風險太大,所以這個任務只透過 AWS CLI 確認目前的狀態,並解釋規則缺失時
會帶來的後果。

```bash
mkdir -p /var/work/tests/artifacts/7

FS_ID=$(aws efs describe-file-systems --region eu-central-1 \
  --query "FileSystems[?Tags[?Key=='Name' && Value=='eks-task107-efs']].FileSystemId" \
  --output text)

MT_SG=$(aws efs describe-mount-targets --region eu-central-1 --file-system-id "$FS_ID" \
  --query 'MountTargets[0].MountTargetId' --output text | \
  xargs -I{} aws efs describe-mount-target-security-groups --region eu-central-1 \
  --mount-target-id {} --query 'SecurityGroups[0]' --output text)

aws ec2 describe-security-groups --region eu-central-1 --group-ids "$MT_SG" \
  --query 'SecurityGroups[0].IpPermissions[?ToPort==`2049`]' \
  > /var/work/tests/artifacts/7/sg-rule.txt
cat /var/work/tests/artifacts/7/sg-rule.txt
```

確認輸出中有一條規則 `FromPort/ToPort: 2049`、`IpProtocol: tcp`,而且來源
(`UserIdGroupPairs`)是叢集節點的 security group,不是一個 CIDR。把成因與後果的診斷存
下來:

```bash
cat > /var/work/tests/artifacts/7/diagnosis.txt <<'EOF'
mount target 的 security group 允許來自叢集節點 security group 的 inbound TCP 2049
(NFS)流量 - 這一點由 aws ec2 describe-security-groups 的輸出(sg-rule.txt)確認。每個
mount target 都需要這條規則:沒有它,efs.csi.aws.com driver 在 API 層面仍然可以建立
mount point,但節點上實際的 mount 過程將無法與 mount target 建立 NFS 連線。

如果這條規則被移除,mount 不會立即以明確的錯誤失敗:發往 2049 port 的 TCP 封包會被
security group 丟棄,節點上的核心會一直等待 NFS 伺服器的回應,直到 timeout 到期。pod
會停留在 Pending/ContainerCreating 狀態,kubectl describe pod 會顯示一個 FailedMount
事件,內容類似「Unable to mount... connection timed out」- 這在表面上看起來更像是網路
緩慢,而不是明確的存取被拒,如果不對 security group 進行診斷,很容易誤以為問題出在 NFS
伺服器本身或子網上。
EOF
cat /var/work/tests/artifacts/7/diagnosis.txt
```

## 快速檢查

```bash
check_result
```
