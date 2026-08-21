[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 122 - リファレンス解答（EKS 向け AWS Backup: composite recovery point、
namespace のリストア）

すべてのコマンドは作業マシン上で SSH 経由で実行します。kubectl と aws CLI はこのラボの
クラスターとリージョン向けに設定済みです。Terraform は AWS Backup 用の IAM ロールと backup
vault をすでに作成しています（コンポーネント `eks_backup_iam`、モジュール
`eks_v2_backup_iam`）- それらの ARN と名前はヒントファイル `~/lab122_hints.txt` にあります。

```bash
cat ~/lab122_hints.txt
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab122_hints.txt | awk '{print $3}')
export CLUSTER_ARN=$(grep '^cluster_arn' ~/lab122_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^backup_role_arn' ~/lab122_hints.txt | awk '{print $3}')
export VAULT_NAME=$(grep '^vault_name' ~/lab122_hints.txt | awk '{print $3}')
```

## タスク 1. Namespace `eks-122`、EBS ボリューム上のワークロード、マーカー

Namespace、Deployment、`gp3` クラス上の PVC（addon `aws-ebs-csi-driver` はコンポーネント
`eks_addon_ebs_irsa` によってすでにインストール済み）、そしてあとでリストアされたオブジェクト
が本当にバックアップ由来であることを確認するためのマーカー入り ConfigMap:

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

`volumeBindingMode: WaitForFirstConsumer` はボリュームの作成を pod がスケジュールされるまで
遅らせます（第 23 章）- PVC が `Bound` になるのは `web` pod が実際にスケジュールされた後
です。artifact に書いたマーカーは、リストアされた ConfigMap が手で作り直したものではなく
バックアップから来たことをあとで証明してくれます。

## タスク 2. リージョンに対する AWS Backup の Amazon EKS opt-in

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

この opt-in がないと、AWS Backup は EKS クラスターを保護可能なリソースとして認識せず、
クラスターに対する `start-backup-job` は失敗します（第 41 章、41.4 節）。

## タスク 3. クラスターの on-demand バックアップ

クラスターは `authentication_mode = "API_AND_CONFIG_MAP"` を明示して作成済みなので（モジュール
`eks_v2_control_plane`）、AWS Backup の認可モードに関する要件はすでに満たされています -
サービスは最初の backup job のときに自分で access entry を作成します。

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

`data` ボリュームの EBS スナップショットはクラスターの状態より組み上がるのに時間がかかること
があるため、特定して `COMPLETED` を待つのではなく終端ステータスを待ちます: `PARTIAL`
（第 41 章、41.4 節）も backup job が終了して recovery point が作られたことを意味し、入れ子の
ポイントの一部が組み上がらなかっただけです。artifact を保存します:

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "backup_job_id=$BACKUP_JOB_ID"
  echo "status=$STATE"
  echo "recovery_point_arn=$RECOVERY_POINT_ARN"
} > /var/work/tests/artifacts/3/backup_status.txt
cat /var/work/tests/artifacts/3/backup_status.txt
```

## タスク 4. composite recovery point の調査

タスク 3 の `RECOVERY_POINT_ARN` は composite recovery point です: 親ポイントがクラスターの
状態の child recovery point と `data` ボリュームの child recovery point を 1 つの整合した
単位としてまとめています（第 41 章、41.4 節）。それ自身と入れ子のポイントを見てみましょう:

```bash
aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --query 'RecoveryPoints[].{Arn:RecoveryPointArn,Parent:ParentRecoveryPointArn,IsParent:IsParent,Status:Status}'

aws backup list-recovery-points-by-backup-vault --backup-vault-name "$VAULT_NAME" \
  --by-parent-recovery-point-arn "$RECOVERY_POINT_ARN"
```

composite ポイントと child ポイントの違いの説明を artifact に保存します:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/composite.txt <<'EOF'
composite recovery point は EKS クラスターの複合的な復旧ポイントです: 複数の入れ子
（nested/child）ポイントを自分の下に 1 つの整合した単位としてまとめます。このラボでは、
クラスターの状態の child recovery point（namespace eks-122 の Kubernetes オブジェクトの
マニフェスト）と、data ボリュームの child recovery point（PVC の背後の EBS スナップショット）
がそれに当たります。

composite ポイントは自分自身の ParentRecoveryPointArn を持ちません - 最上位だからです。各
child ポイントの ParentRecoveryPointArn フィールドは composite ポイントの ARN を参照し、
IsParent=true が付くのは composite の方だけです。クラスターの状態の child は親と 1:1 で
結び付いており、単独でコピー、削除、切り離しはできません。一方でボリュームの child ポイントは
composite とは別に、コピー、削除、リストアが可能です。

だからこそ composite ポイントは中に入れ子のポイントがある間は削除できません - 先に nested
ポイントを削除するか切り離し、そのあとで初めて composite 自体を削除できます。
EOF
cat /var/work/tests/artifacts/4/composite.txt
```

## タスク 5. Namespace restore（non-destructive）

composite recovery point の restore を、namespace `eks-122` を指定して同じ（稼働中の）
クラスターに対して開始します:

ここでは `namespaceLevelRestore` だけでは足りません。composite ポイントには EBS スナップ
ショットも含まれており、それを復元するために AWS Backup は**ボリュームを作る Availability
Zone を必ず要求します**。指定しないと、ボリュームの child restore job は
`Restore Job failed as no restore metadata was provided` で失敗し、親は
`All PV restore jobs failed to restore` で失敗します。これは `nestedRestoreJobs` パラメーター
で渡します: `入れ子ポイントの ARN -> そのメタデータ` のマップです。ゾーンは既存のノードから
取ります。そうしないとボリュームはマウントする相手のいない場所に作られてしまいます。

エンコードの入れ子構造に注意してください: `nestedRestoreJobs` の値は JSON 文字列で、その中に
マップがあり、マップの各要素の値もまた JSON 文字列です。クォートが 1 段多いとエラー
`Invalid JSON format in NestedRestoreMetadata` になるので、`jq` で組み立てます（最初の呼び出し
の `-r` に注目してください - これが余分な段を取り除きます）:

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

Deployment `web` と ConfigMap `marker` が重複していないこと、マーカーがタスク 1 で保存した値
と一致することを確認します - これが restore の non-destructive な挙動の証明です（第 42 章、
42.2 節）: クラスターに同じ名前で既に存在するオブジェクトは上書きされずスキップされるだけな
ので、稼働中の namespace への restore は 2 つ目のコピーを作りません。

```bash
kubectl rollout status deployment/web -n eks-122
kubectl get cm marker -n eks-122 -o jsonpath='{.data.marker}'; echo
cat /var/work/tests/artifacts/1/marker.txt; echo
```

説明を含む artifact を保存します:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/restore_status.txt <<EOF
restore_job_id=$RESTORE_JOB_ID
status=$STATUS
AWS Backup の restore は常に non-destructive です: 対象の namespace に既に存在する
Kubernetes オブジェクトは上書きされず、スキップされます。restore の時点で Deployment web と
ConfigMap marker は同じ内容で eks-122 に既に存在していたため、restore はそれらの重複を作らず、
マーカーの値も変えませんでした - オブジェクトは単に一致したのでスキップされました。
EOF
cat /var/work/tests/artifacts/5/restore_status.txt
```

## タスク 6. クラスターのバージョンのロールバックが `kubectl delete namespace` を取り消せない理由

第 41 章 41.1 節の動機付けの例: エンジニアが誤って別のクラスターに対して
`kubectl delete namespace prod` を実行してしまい、最初に思い浮かぶのは「ロールバックしよう」
です。しかしロールバックするものが何もありません。

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/whynonrollback.txt <<'EOF'
クラスターのバージョンの rollback（第 39 章）が扱うのは control plane とその Kubernetes
バージョンであり、Kubernetes のオブジェクトやボリュームの中身を保存したり戻したりはしません。
kubectl delete namespace が消したオブジェクトは etcd の中に存在しますが、EKS の etcd は
managed です: 直接アクセスする手段はなく、セルフマネージドなクラスターのように etcd の dump を
取って手で復元することもできません。managed な control plane に「昨日の状態に戻す」ような
コマンドも存在しません。

だからこそ、削除された namespace を取り戻す唯一有効な方法は、あらかじめ AWS Backup で取った
クラスター状態のバックアップ（タスク 3-4）と、それに続く restore（タスク 5）であって、
control plane のバージョンの rollback ではありません。
EOF
cat /var/work/tests/artifacts/6/whynonrollback.txt
```

## クイックチェック

```bash
check_result
```
