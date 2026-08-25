[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 106 - 参考解答(EBS CSI:gp3、AZ への紐付け、拡張、スナップショット)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl は既にクラスタに
対して設定済みです。ドライバ `aws-ebs-csi-driver`(プロビジョナー `ebs.csi.aws.com`)は
既に managed addon としてインストールされており、IRSA によるロール(コンポーネント
`eks_addon_ebs_irsa`)も設定済みです - ロールを改めて作成する必要はありません。

## タスク 1. Namespace `eks-106`

```bash
kubectl create namespace eks-106
```

## タスク 2. StorageClass `gp3-immediate`(壊れた構成)

意図的に `volumeBindingMode: Immediate` を選びます - これがまさにボリュームを任意の
ゾーンに捕まえてしまう設定です:

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

## タスク 3. `gp3-immediate` 上の StatefulSet `db`

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

このラボのクラスタは 2 つの AZ(`eu-central-1a` と `eu-central-1b`)上に構築されて
います。`Immediate` では、ドライバはスケジューラが Pod をどこに配置するか決まるのを
待たずに、PVC が現れた直後にボリュームを作成します。そのため、ボリュームのゾーンは
Karpenter が実際にどこにノードを立ち上げるかとは無関係に選ばれます。2 つの AZ では
`volume node affinity conflict` が実際に発生することがありますが、毎回の実行で必ず
起きるわけではありません:ボリュームが偶然、既に適切なノードがあるゾーンに入ることも
あります。そのため、タスク 4 での診断は結果に関わらず必須です。

## タスク 4. 診断:Immediate の症状と AZ への紐付け

```bash
mkdir -p /var/work/tests/artifacts/4

kubectl describe pod db-0 -n eks-106 | sed -n '/Events/,$p' \
  > /var/work/tests/artifacts/4/describe.txt

PV=$(kubectl get pvc data-db-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
kubectl get pv "$PV" -o yaml > /var/work/tests/artifacts/4/pv.yaml
grep -A6 nodeAffinity /var/work/tests/artifacts/4/pv.yaml
```

Pod が実際にどこに配置されたか、ボリュームのゾーンとノードのゾーンが一致しているかを
確認します:

```bash
PHASE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.status.phase}')
NODE=$(kubectl get po db-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "phase=$PHASE node=$NODE pv_zone=$PV_ZONE"
```

説明をアーティファクトに保存します。この文言は Pod が `Pending` のままの場合でも、
たまたま運が良かった場合でも、どちらでも当てはまるようにします:

```bash
cat > /var/work/tests/artifacts/4/diagnosis.txt <<'EOF'
StorageClass gp3-immediate は volumeBindingMode: Immediate を使っている。これは、
CSI ドライバ ebs.csi.aws.com が、スケジューラが Pod のノードを選ぶ前に、PVC が現れた
直後に EBS ボリュームを作成することを意味する。ボリュームのゾーンは PV の
spec.nodeAffinity.required.nodeSelectorTerms[].matchExpressions[].key:
topology.ebs.csi.aws.com/zone に固定され、スケジューラはこの紐付けを尊重する義務がある。

Pod db-0 が Pending の場合、kubectl describe pod にはイベント
"0/N nodes are available: N node(s) had volume node affinity conflict" が表示される -
ボリュームが、適切なノードが存在しないゾーンに作成されたことを示している。

Pod db-0 が Running の場合でも、それは構成が正しいことを意味しない:クラスタには
2 つの AZ(eu-central-1a、eu-central-1b)しかなく、Immediate ではボリュームが偶然
ノードが既に存在するゾーンに入っただけである。別の実行時や、Karpenter による
consolidation の際、あるいはより多くの AZ を持つ環境に移した場合、同じ StorageClass は
再び volume node affinity conflict を引き起こす。確実に正しく動作するのは
WaitForFirstConsumer だけであり、そこではボリュームのゾーンが常に既に選ばれたノードの
ゾーンと一致する - これがタスク 5 の内容である。
EOF
cat /var/work/tests/artifacts/4/diagnosis.txt
```

## タスク 5. 修正:`WaitForFirstConsumer` を使った StorageClass `gp3`

PVC は自分の StorageClass に一度だけ紐付けられ、既存の PVC のクラスを変更することは
できません。そのため、`gp3-immediate` にパッチを当てるのではなく、新しいクラスと新しい
StatefulSet で修正します:

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

`WaitForFirstConsumer` では、スケジューラが `db-fixed-0` のノードを選ぶまでボリュームの
プロビジョニングが延期されます。そのあとになってようやくドライバがそのノードのゾーンに
ボリュームを作成するため、`nodeAffinity` の競合は構造上発生し得ません。ボリュームの
ゾーンがノードのゾーンと一致することを確認します:

```bash
NODE=$(kubectl get po db-fixed-0 -n eks-106 -o jsonpath='{.spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
PV=$(kubectl get pvc data-db-fixed-0 -n eks-106 -o jsonpath='{.spec.volumeName}')
PV_ZONE=$(kubectl get pv "$PV" \
  -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
echo "node_zone=$NODE_ZONE pv_zone=$PV_ZONE"
```

`node_zone` と `pv_zone` の値は一致するはずです - これは偶然ではなく正しく動作している
ことの証です。さらに、特定の AZ をボリュームのプロビジョニングから除外する必要がある
場合は、StorageClass の `allowedTopologies`(キー `topology.ebs.csi.aws.com/zone`)で
明示的にゾーンの集合を制限することもできます。

## タスク 6. ボリューム `data-db-fixed-0` を 5Gi から 10Gi に拡張する

`gp3` の `allowVolumeExpansion: true` により、Pod を再作成せずにオンラインで拡張する
ことができます:

```bash
kubectl patch pvc data-db-fixed-0 -n eks-106 \
  -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'

# CSI ドライバがボリュームとファイルシステムの変更を完了するまで待つ
until [[ "$(kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}')" == "10Gi" ]]; do
  sleep 5
done

kubectl get pvc data-db-fixed-0 -n eks-106 \
  -o jsonpath='{.status.capacity.storage}'
echo
```

ボリュームを縮小することはできません - 拡張のみが可能で、かつ EBS の変更回数の制限を
超えない頻度でのみ行えます。

## タスク 7. ボリュームのスナップショットと復元(best effort)

スナップショットは 3 つのオブジェクトを通じて機能します:`VolumeSnapshotClass`、
`VolumeSnapshot`、そして自動的に作成される `VolumeSnapshotContent` です。
snapshot-controller と CRD は managed addon `snapshot-controller`(コンポーネント
`eks_addons`)によってクラスタに既にインストールされています:

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

スナップショットが準備完了(`readyToUse: true`)になるのを待ち、それを新しい PVC に
復元します。EBS のスナップショットはリージョナルなオブジェクトですが、そこから復元
されたボリュームは再びゾーナルになるため、ここでも `WaitForFirstConsumer` のクラスが
必要です:

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

`data-restored` は Pod がアクセスするまで `Pending` のままです(クラス `gp3` は
`WaitForFirstConsumer` のため)。これは想定どおりで、復元されたボリュームの
プロビジョニングもスケジューリングまで延期されるからです。何らかの理由でクラスタに
snapshot-controller や CRD が存在しない場合でも、このタスク自体はラボの他の部分を
妨げません - これは検証における独立した任意のステップです。

## クイックチェック

```bash
check_result
```
