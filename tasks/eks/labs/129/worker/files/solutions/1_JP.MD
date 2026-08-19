[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ129 - 参考解答(Mountpoint for S3: ファイルのセマンティクスとバックアップ)

すべてのコマンドはワーカーマシン上でSSH経由で実行します。kubectlはすでにクラスタに
対して設定されています。ドライバ`aws-mountpoint-s3-csi-driver`(provisioner
`s3.csi.aws.com`)は、IRSA経由のロール(コンポーネント`eks_addon_s3_csi_irsa`)を持
つmanaged addonとしてすでにインストールされており、versioningを有効にしたbucketと
テストオブジェクト`readme.txt`もすでにterraformによって作成されています。

## タスク1. Namespace `eks-129`

```bash
kubectl create namespace eks-129
```

## タスク2. 実際のbucketに対する静的PV/PVC

実際のbucketの名前を見つけます:

```bash
BUCKET=$(aws s3api list-buckets \
  --query "Buckets[?contains(Name,'mountpoint-demo')].Name" --output text)
echo "$BUCKET"
```

Mountpointには静的プロビジョニングしかありません: PVは手動で書き、すでに存在する
bucketを参照します。

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: s3-pv
spec:
  capacity:
    storage: 1200Gi
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  claimRef:
    namespace: eks-129
    name: s3-pvc
  mountOptions:
    - region eu-central-1
  csi:
    driver: s3.csi.aws.com
    volumeHandle: s3-csi-demo-volume
    volumeAttributes:
      bucketName: $BUCKET
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: s3-pvc
  namespace: eks-129
spec:
  accessModes: ["ReadWriteMany"]
  storageClassName: ""
  resources:
    requests:
      storage: 1200Gi
  volumeName: s3-pv
EOF

kubectl get pv s3-pv
kubectl get pvc s3-pvc -n eks-129
```

`capacity`/`requests.storage`はプレースホルダの値です。スキーマ上は必須ですが、
Mountpointはこれらを無視します: 実際のサイズはbucketの内容によって決まります。

## タスク3. 成功する操作: 新しいファイルと読み取り

このPVCを持つpodを立ち上げます:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mountpoint-app
  namespace: eks-129
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mountpoint-app
  template:
    metadata:
      labels:
        app: mountpoint-app
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-c", "sleep 86400"]
        volumeMounts:
        - name: s3
          mountPath: /data
      volumes:
      - name: s3
        persistentVolumeClaim:
          claimName: s3-pvc
EOF

kubectl rollout status deployment/mountpoint-app -n eks-129
POD=$(kubectl get po -n eks-129 -l app=mountpoint-app -o jsonpath='{.items[0].metadata.name}')
```

ここでのイメージはあえて`busybox`にしています。コースの他のラボのアプリケーションで
はありません: `viktoruj/ping_pong`には`sh`も`cat`もなく、`kubectl exec`で入ると
`exec: "sh": executable file not found in $PATH`と応答されます(確認済み)。このラボ
全体はpod内部のファイルシステム操作についてのものなので、shellと`mv`、`dd`を持つイ
メージが必要です。podは単に生き続ければよいので、`command`には`sleep`を使っていま
す。

新しいファイルの作成 - これは先頭からの順次書き込みで、オブジェクト全体に対する
`PutObject`のモデルに収まるため、成功します:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec "$POD" -n eks-129 -- sh -c 'echo test > /data/newfile.txt && cat /data/newfile.txt' \
  > /var/work/tests/artifacts/3/create.txt
cat /var/work/tests/artifacts/3/create.txt
```

読み取りも、bucket内に既存のオブジェクト`readme.txt`を読む場合も含めて正常に動作し
ます - これは`GetObject`です:

```bash
kubectl exec "$POD" -n eks-129 -- cat /data/readme.txt \
  > /var/work/tests/artifacts/3/read.txt
cat /var/work/tests/artifacts/3/read.txt
```

## タスク4. 症状: `rename`が失敗する

リネームはオブジェクトストレージ上では安価な操作ではなく、Mountpointは通常の
bucketに対してこれを明確に拒否します:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$POD" -n eks-129 -- \
  mv /data/newfile.txt /data/renamed.txt \
  > /var/work/tests/artifacts/4/rename.txt 2>&1
cat /var/work/tests/artifacts/4/rename.txt
```

出力には`mv: can't rename '/data/newfile.txt': Function not implemented`が現れます
(検証環境で確認済み、ドライババージョンv1.15.0-eksbuild.1、busybox 1.36)。ここで
errnoに注目してください: これは`ENOSYS`であり、Mountpointはシステムコール`rename`
を一切実装していません。タスク5では別の種類の失敗が現れます - `EPERM`、
`Operation not permitted`です: そちらでは操作は実装されているものの、マウント設定に
よって禁止されています。当番作業でこれらを区別するのは有用です: `ENOSYS`は「この機
能はドライバに存在せず、今後も存在しない」ことを意味し、`EPERM`は「別のmount
optionsであれば動くかもしれない」ことを意味します。

このとき、ファイル`newfile.txt`はそのまま残り、`renamed.txt`は現れません: 操作は開
始されず、bucketが中間状態に陥ることもありません。AWS側から確認できます:

```bash
aws s3api list-objects-v2 --bucket "$BUCKET" --query 'Contents[].Key' --output text
```

## タスク5. 症状: append(追加書き込み)とファイルの途中への書き込みが失敗する

両方のケースは、すでに存在するオブジェクトへの部分的な変更を試みるものであり、S3の
オブジェクトは不変であり、新しい`PutObject`によって全体としてのみ更新されます:

```bash
mkdir -p /var/work/tests/artifacts/5

{
  echo "=== append(echo >>) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo more >> /data/newfile.txt' 2>&1

  echo
  echo "=== ファイルの途中への書き込み(dd seek + conv=notrunc) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c \
    'echo patched | dd of=/data/newfile.txt bs=1 seek=1 conv=notrunc' 2>&1

  echo
  echo "=== 既存ファイルの上書き(allow-overwriteが必要) ==="
  kubectl exec "$POD" -n eks-129 -- sh -c 'echo test2 > /data/newfile.txt' 2>&1

  echo
  echo "=== ファイルの削除(allow-deleteが必要) ==="
  kubectl exec "$POD" -n eks-129 -- rm /data/newfile.txt 2>&1

  echo
  echo "説明: S3オブジェクトは不変です。キーの更新はオブジェクト全体に対する新しい"
  echo "PutObjectであるため、Mountpointはすでにアップロードされたファイルの末尾に"
  echo "追記(append)したり、途中のバイトを変更したりすることができません -"
  echo "どちらの操作もOperation not permittedで明確に失敗し、静かにデータを破損さ"
  echo "せることはありません。同じ理由から、デフォルトでは上書きと削除も禁止されて"
  echo "います: これらはmount optionsのallow-overwriteとallow-deleteによって有効に"
  echo "なり、それを有効にするかどうかは意識的に判断すべきです。"
} > /var/work/tests/artifacts/5/writesemantics.txt

cat /var/work/tests/artifacts/5/writesemantics.txt
```

上記の4つの失敗はすべて同じ`EPERM`であり、いずれもマウント設定によって解除されたり
されなかったりします。これはタスク4の`rename`とは異なります。有用な対比: `mkdir
/data/sub`は黙って、エラーなしで通過します。S3内のディレクトリは仮想的なものであ
り、それに対してオブジェクトが作成されないためです。`aws s3api list-objects-v2`にも
新しいキーは表示されません。一方、存在しないネストしたプレフィックスへの書き込み
(`echo x > /data/sub2/nested.txt`)は`nonexistent directory`で失敗します: 先に
`mkdir`が必要です。これはまさに第25章が警告している「ほぼファイルシステム」というも
のです。

## タスク6. なぜAWS Backupによるバックアップがなく、versioningがあるのか

EKS向けのAWS Backup(第41-42章)は、CSIスナップショットを通じてEBSボリュームのデー
タを保護します。Mountpointボリュームには内部にEBSが一切ありません: `/data`内のファ
イルはS3 bucketのオブジェクトであり、ディスク上のブロックではないため、PVC
`s3-pvc`には`gp3`ボリューム(第23章)が持つのと同じ意味でのスナップショット
(snapshot)がありません。ここでデータを保護しているのはS3自身です - まずbucketの
versioningです。terraformが事前にこれを有効にしています
(`aws_s3_bucket_versioning`):

```bash
mkdir -p /var/work/tests/artifacts/6

{
  echo "=== aws s3api get-bucket-versioning --bucket $BUCKET ==="
  aws s3api get-bucket-versioning --bucket "$BUCKET"

  echo
  echo "説明: PVC s3-pvcはMountpoint S3 CSI経由でマウントされており、EBS CSI経由で"
  echo "はありません。データはすでにS3内にオブジェクトとして存在しており、ブロッ"
  echo "クデバイス上にはないため、このボリュームにはAWS Backup for EKSによるスナ"
  echo "ップショットがありません(その仕組みはEBS VolumeSnapshot経由で動作しま"
  echo "す、第41章)。このようなbucket上で、誤った上書きや削除からデータを守るの"
  echo "は、versioning(terraformによって有効化済み)とS3自体のlifecycleポリシー"
  echo "であり、ボリューム全体のバックアップではありません。"
} > /var/work/tests/artifacts/6/backup.txt

cat /var/work/tests/artifacts/6/backup.txt
```

## クイックチェック

```bash
check_result
```
