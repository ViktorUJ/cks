[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 107 - エタロン解決策(EFS CSI: AZ 間の ReadWriteMany)

すべてのコマンドは SSH 経由で worker マシン上で実行します。kubectl はすでにクラスターに
対して設定済みです。`aws-efs-csi-driver` driver(provisioner `efs.csi.aws.com`)は、
IRSA によるロールを持つ managed addon としてすでにインストールされており
(コンポーネント `eks_addon_efs_irsa`)、EFS ファイルシステムと各 AZ の mount target は
terraform によってすでに作成されています - 再度作成する必要はありません。

## タスク 1. Namespace `eks-107`

```bash
kubectl create namespace eks-107
```

## タスク 2. 実際の `fileSystemId` を指す StorageClass `efs-sc`

ファイルシステムは事前に terraform によって作成されており、driver はその上で動作する
だけです。AWS CLI でその ID を見つけます(タグ `Name` はラボの `prefix` から組み立て
られています):

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

`provisioningMode: efs-ap` は動的プロビジョニングを意味します: 各 PVC に対して driver は
ファイルシステム全体を渡すのではなく、このファイルシステム内に個別の access point を
作成します。

## タスク 3. PVC `shared-data`(`ReadWriteMany`、`5Gi`)

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

EFS はリージョン単位のシステムなので、PVC は後で Pod がどのゾーンに配置されるかに関わらず
`Bound` に遷移します: mount target は、それが作成されているどの AZ からでも到達可能です。

## タスク 4. Deployment `writer`(3 レプリカ、異なる AZ、共有 PVC)

key `topology.kubernetes.io/zone` に対する `topologySpreadConstraints` により、
スケジューラーはレプリカを異なるゾーンに分散させます:

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

レプリカが異なる AZ に配置されたことを確認します:

```bash
kubectl get po -n eks-107 -l app=writer \
  -o custom-columns='POD:.metadata.name,NODE:.spec.nodeName' --no-headers | \
  while read -r pod node; do
    zone=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
    echo "$pod  node=$node  zone=$zone"
  done
```

3 つのレプリカすべてが異なる AZ にありながら、同時に `Running` になり、同じ PVC
`shared-data` をマウントしています。EBS ではこれは不可能です(`ReadWriteOnce`、エラー
`Multi-Attach error`)。なぜなら EBS はゾーン単位のブロック volume であるのに対し、EFS は
各ゾーンに mount target を持つリージョン単位の NFS システムだからです。

## タスク 5. 共有アクセス: あるレプリカから書き込み、別のレプリカから読み取り

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

Pod `$WRITER_POD` が 1 つの AZ で書き込んだ行が、別の AZ にある Pod `$READER_POD` から
読み取れます - これは、ノードのディスク上のローカルコピーではなく、NFS 経由の本当に
共有されたネットワーク volume であることを確認するものです。

## タスク 6. ゾーンごとの `nodeAffinity` が存在しないことの確認

```bash
mkdir -p /var/work/tests/artifacts/6

PV=$(kubectl get pvc shared-data -n eks-107 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/6/pv.yaml
grep -A3 nodeAffinity /var/work/tests/artifacts/6/pv.yaml
echo "exit code: $?"

cat > /var/work/tests/artifacts/6/explanation.txt <<'EOF'
efs.csi.aws.com が作成する PV には spec.nodeAffinity セクションがない(EBS とは異なり、
第 23 章では nodeAffinity がキー topology.ebs.csi.aws.com/zone を介して特定の AZ を
固定する)。理由は、EFS が各 AZ に mount target を持つリージョン単位のファイルシステム
だからであり、この volume を使う pod はクラスターの他のどのゾーンでも再作成でき、新しい
ゾーンの mount target を通じて同じデータを見続けられる。scheduler は、EBS の場合のように
この volume を理由に pod を特定のノードやゾーンに固定する必要がない。
EOF
cat /var/work/tests/artifacts/6/explanation.txt
```

`grep -A3 nodeAffinity` コマンドは何も見つけません(出力は空、終了コード `1`) - これが
そのセクションが存在しないことの確認です。ラボ 106(EBS)の `pv.yaml` と比較してみて
ください。そこでは `spec.nodeAffinity.required.nodeSelectorTerms` が volume のゾーンを
厳格に固定しています。

## タスク 7. 診断: mount target の SG と 2049 番ポート(読み取り専用)

実際のインフラを壊すのはリスクが高いため、このタスクは AWS CLI で現在の状態を確認し、
ルールが存在しない場合の影響を説明するだけです。

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

出力に `FromPort/ToPort: 2049`、`IpProtocol: tcp` のルールがあり、送信元
(`UserIdGroupPairs`)が CIDR ではなくクラスターノードの security group であることを
確認してください。原因と結果の診断を保存します:

```bash
cat > /var/work/tests/artifacts/7/diagnosis.txt <<'EOF'
mount target の security group は、クラスターノードの security group からの inbound
TCP 2049(NFS)を許可している - これは aws ec2 describe-security-groups の出力
(sg-rule.txt)によって確認できる。このルールはすべての mount target に必要である:これが
無くても efs.csi.aws.com driver は API レベルでは mount point を作成できるが、ノード上の
実際のマウント処理は mount target との NFS 接続を確立できない。

このルールが削除された場合、マウントは明示的なエラーで即座に失敗するわけではない: 2049
番ポートへの TCP パケットは security group によって破棄され、ノード上のカーネルは
タイムアウトが切れるまで NFS サーバーの応答を待ち続ける。pod は Pending/
ContainerCreating のままになり、kubectl describe pod には「Unable to mount...
connection timed out」のようなテキストを含む FailedMount イベントが表示される -
これは明示的なアクセス拒否ではなく遅いネットワークのように見えるため、security group を
診断しないと、原因を NFS サーバー自体やサブネットの問題と誤解しやすい。
EOF
cat /var/work/tests/artifacts/7/diagnosis.txt
```

## クイックチェック

```bash
check_result
```
