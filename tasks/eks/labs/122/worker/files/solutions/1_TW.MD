[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 122 - 參考解答（EKS 的 AWS Backup：composite recovery point、
namespace 還原）

所有指令都在工作機上透過 SSH 執行。kubectl 與 aws CLI 已針對本實驗的叢集與區域設定完成。
Terraform 已經建立了 AWS Backup 用的 IAM 角色與 backup vault（元件 `eks_backup_iam`，模組
`eks_v2_backup_iam`）- 它們的 ARN 與名稱都在提示檔 `~/lab122_hints.txt` 裡。

```bash
cat ~/lab122_hints.txt
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab122_hints.txt | awk '{print $3}')
export CLUSTER_ARN=$(grep '^cluster_arn' ~/lab122_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^backup_role_arn' ~/lab122_hints.txt | awk '{print $3}')
export VAULT_NAME=$(grep '^vault_name' ~/lab122_hints.txt | awk '{print $3}')
```

## 任務 1。Namespace `eks-122`、EBS 卷上的工作負載與標記

Namespace、Deployment、`gp3` class 上的 PVC（addon `aws-ebs-csi-driver` 已由元件
`eks_addon_ebs_irsa` 安裝好），以及一個帶標記的 ConfigMap，稍後用它確認還原出來的物件真的
來自備份：

```bash
kubectl create namespace eks-122

cat <<'EOF' | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
  namespace: eks-122
spec:
  storageClassName: gp3
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 5Gi
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-122
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: data
EOF

kubectl rollout status deployment/web -n eks-122

MARKER="MARKER_LAB122_$(tr -dc a-z0-9 </dev/urandom | head -c 8)"
kubectl create configmap marker -n eks-122 --from-literal=marker="$MARKER"

mkdir -p /var/work/tests/artifacts/1
echo -n "$MARKER" > /var/work/tests/artifacts/1/marker.txt
cat /var/work/tests/artifacts/1/marker.txt
```

`volumeBindingMode: WaitForFirstConsumer` 會把卷的建立延後到 pod 被排程之後（第 23 章）-
PVC 只有在 `web` pod 真的被排程後才會變成 `Bound`。artifact 裡的標記稍後可以證明還原出來的
ConfigMap 來自備份，而不是手動重建的。

## 任務 2。為該區域在 AWS Backup 中啟用 Amazon EKS 的 opt-in

```bash
mkdir -p /var/work/tests/artifacts/2
BEFORE=$(aws backup describe-region-settings \
  --query "ResourceTypeOptInPreference.EKS" --output text)
echo "before=$BEFORE" > /var/work/tests/artifacts/2/optin.txt

if [[ "$BEFORE" != "True" ]]; then
  aws backup update-region-settings \
    --resource-type-opt-in-preference '{"EKS":true}'
fi

AFTER=$(aws backup describe-region-settings \
  --query "ResourceTypeOptInPreference.EKS" --output text)
echo "after=$AFTER" >> /var/work/tests/artifacts/2/optin.txt
cat /var/work/tests/artifacts/2/optin.txt
```

沒有這個 opt-in，AWS Backup 就不會把 EKS 叢集視為可保護的資源，對叢集執行
`start-backup-job` 會失敗（第 41 章，41.4 節）。

## 任務 3。叢集的 on-demand backup

叢集建立時就已經明確帶了 `authentication_mode = "API_AND_CONFIG_MAP"`（模組
`eks_v2_control_plane`），所以 AWS Backup 對授權模式的要求早就滿足了 - 服務會在第一個
backup job 時自己建立 access entry。

```bash
BACKUP_JOB_ID=$(aws backup start-backup-job \
  --backup-vault-name "$VAULT_NAME" \
  --resource-arn "$CLUSTER_ARN" \
  --iam-role-arn "$ROLE_ARN" \
  --query 'BackupJobId' --output text)

echo "backup_job_id=$BACKUP_JOB_ID"

while true; do
  STATE=$(aws backup describe-backup-job --backup-job-id "$BACKUP_JOB_ID" \
    --query 'State' --output text)
  echo "backup job state: $STATE"
  case "$STATE" in
    COMPLETED|PARTIAL|FAILED|ABORTED|EXPIRED) break ;;
  esac
  sleep 15
done

RECOVERY_POINT_ARN=$(aws backup describe-backup-job --backup-job-id "$BACKUP_JOB_ID" \
  --query 'RecoveryPointArn' --output text)
```

`data` 卷的 EBS 快照組成的時間可能比叢集狀態更久，所以我們等的是終態，而不是特定的
`COMPLETED`：`PARTIAL`（第 41 章，41.4 節）同樣表示 backup job 已結束且 recovery point 已
建立，只是其中某些巢狀還原點可能沒有組好。存下 artifact：

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "backup_job_id=$BACKUP_JOB_ID"
  echo "status=$STATE"
  echo "recovery_point_arn=$RECOVERY_POINT_ARN"
} > /var/work/tests/artifacts/3/backup_status.txt
cat /var/work/tests/artifacts/3/backup_status.txt
```

## 任務 4。診斷 composite recovery point

任務 3 得到的 `RECOVERY_POINT_ARN` 就是一個 composite recovery point：父還原點把叢集狀態的
child recovery point 與 `data` 卷的 child recovery point 組成一個一致的單位（第 41 章，
41.4 節）。我們來看看它和它的巢狀還原點：

```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --query 'RecoveryPoints[].{Arn:RecoveryPointArn,Parent:ParentRecoveryPointArn,IsParent:IsParent,Status:Status}'

aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN"
```

把 composite 與 child 還原點差異的解釋存進 artifact：

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/composite.txt <<'EOF'
composite recovery point 是 EKS 叢集的複合還原點：它把若干個巢狀（nested/child）還原點歸到
自己底下，構成一個一致的單位。對這個實驗來說，那就是叢集狀態的 child recovery point
（namespace eks-122 的 Kubernetes 物件清單）與 data 卷的 child recovery point（PVC 背後的
EBS 快照）。

composite 還原點自己沒有 ParentRecoveryPointArn - 它就是最上層。每個 child 還原點的
ParentRecoveryPointArn 欄位都指向 composite 還原點的 ARN，而 IsParent=true 只會標在
composite 上。叢集狀態的 child 與父還原點是 1:1 的綁定：它無法單獨被複製、刪除或分離。相反
地，卷的 child 還原點可以獨立於 composite 被複製、刪除與還原。

正因如此，只要 composite 裡面還有巢狀還原點，它就無法被刪除 - 必須先刪除或分離 nested
還原點，之後才能刪 composite 本身。
EOF
cat /var/work/tests/artifacts/4/composite.txt
```

## 任務 5。Namespace restore（non-destructive）

我們對 composite recovery point 發起 restore，指定 namespace `eks-122`，還原到同一個（正在
運行的）叢集：

這裡只有 `namespaceLevelRestore` 是不夠的。composite 還原點裡還有一個 EBS 快照，要還原它，
AWS Backup **一定會要求提供 Availability Zone**，也就是卷要建在哪裡。若不提供，卷的 child
restore job 會以 `Restore Job failed as no restore metadata was provided` 失敗，父 job 則以
`All PV restore jobs failed to restore` 失敗。這是透過 `nestedRestoreJobs` 參數傳入的：一個
`巢狀還原點 ARN -> 它的中介資料` 的對應表。可用區取自現有的節點，否則卷會被建立在沒人能掛載
它的地方。

注意編碼的巢狀層次：`nestedRestoreJobs` 的值是一個 JSON 字串，裡面是一個對應表，而對應表中
每個元素的值本身又是一個 JSON 字串。多一層引號就會得到錯誤
`Invalid JSON format in NestedRestoreMetadata`，所以我們用 `jq` 來組（注意第一次呼叫裡的
`-r` - 就是它去掉了多出來的那一層）：

```bash
AZ=$(kubectl get nodes -l 'eks.amazonaws.com/compute-type notin (fargate)' \
  -o jsonpath='{.items[0].metadata.labels.topology\.kubernetes\.io/zone}')

SNAP_ARN=$(aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN" \
  --query 'RecoveryPoints[?ResourceType==`EBS`].RecoveryPointArn' --output text)

NESTED=$(jq -rn --arg s "$SNAP_ARN" --arg az "$AZ" \
  '{($s): ({AvailabilityZone: $az} | tostring)} | tostring')

METADATA=$(jq -cn --arg c "$CLUSTER_NAME" --arg n "$NESTED" \
  '{clusterName: $c, newCluster: "false", namespaceLevelRestore: "true",
    namespaces: "[\"eks-122\"]", nestedRestoreJobs: $n}')

RESTORE_JOB_ID=$(aws backup start-restore-job \
  --recovery-point-arn "$RECOVERY_POINT_ARN" \
  --iam-role-arn "$ROLE_ARN" \
  --resource-type EKS \
  --metadata "$METADATA" \
  --query 'RestoreJobId' --output text)

echo "restore_job_id=$RESTORE_JOB_ID"

while true; do
  STATUS=$(aws backup describe-restore-job --restore-job-id "$RESTORE_JOB_ID" \
    --query 'Status' --output text)
  echo "restore job status: $STATUS"
  case "$STATUS" in
    COMPLETED|FAILED|ABORTED) break ;;
  esac
  sleep 15
done
```

我們檢查 Deployment `web` 與 ConfigMap `marker` 沒有被重複建立，而且標記與任務 1 存下的值
一致 - 這證明了 restore 的 non-destructive 行為（第 42 章，42.2 節）：叢集中已存在的同名
物件不會被覆寫，只會被略過，所以對正在運行的 namespace 做 restore 不會產生第二份副本。

```bash
kubectl rollout status deployment/web -n eks-122
kubectl get cm marker -n eks-122 -o jsonpath='{.data.marker}'; echo
cat /var/work/tests/artifacts/1/marker.txt; echo
```

存下帶有解釋的 artifact：

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/restore_status.txt <<EOF
restore_job_id=$RESTORE_JOB_ID
status=$STATUS
AWS Backup 中的 restore 永遠是 non-destructive 的：目標 namespace 中已存在的 Kubernetes
物件不會被覆寫，只會被略過。restore 的時候 Deployment web 與 ConfigMap marker 已經以相同的
內容存在於 eks-122 中，所以 restore 沒有為它們建立重複物件，也沒有改動標記的值 - 這些物件
只是被判定為相同而被略過。
EOF
cat /var/work/tests/artifacts/5/restore_status.txt
```

## 任務 6。為什麼回退叢集版本無法撤銷 `kubectl delete namespace`

第 41 章 41.1 節的引導範例：一位工程師誤在錯的叢集上執行了
`kubectl delete namespace prod`，第一個念頭是「把它回退掉」。可是根本沒有東西可以回退。

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/whynonrollback.txt <<'EOF'
叢集版本的 rollback（第 39 章）處理的是 control plane 與它的 Kubernetes 版本 - 它既不保存
也不會還原 Kubernetes 物件或卷的內容。被 kubectl delete namespace 刪掉的那些物件住在 etcd
裡，而在 EKS 中 etcd 是 managed 的：沒有直接存取的途徑，也沒辦法像自管叢集那樣取出 etcd 的
dump 再手動還原。對於 managed control plane 也不存在「把它變回昨天的樣子」這種指令。

正因如此，要找回被刪除的 namespace，唯一可行的辦法是事先用 AWS Backup 做好的叢集狀態備份
（任務 3-4）再加上 restore（任務 5），而不是 control plane 版本的 rollback。
EOF
cat /var/work/tests/artifacts/6/whynonrollback.txt
```

## 快速檢查

```bash
check_result
```
