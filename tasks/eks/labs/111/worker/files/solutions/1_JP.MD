[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 111 - 参考解答(spot ノード:多様化、割り込み、graceful drain)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl は既にクラスタ向け
に設定されています(kubeconfig はマシン起動時に `aws eks update-kubeconfig` で組み立て
られています)。

## タスク 1. Namespace `eks-111`

```bash
kubectl create namespace eks-111
```

## タスク 2. toleration と graceful shutdown を持つ spot プール上の Deployment `spotapp`

プール `spot-lab` は taint `dedicated=spot-lab:NoSchedule` で閉じられているため、Pod
は対応する toleration を持つ必要があります。そうでなければ Karpenter はこの NodePool
に Pod を配置できません。`terminationGracePeriodSeconds: 60` は spot 割り込みの 2 分間
のウィンドウに収まり、`sleep 5` を伴う `preStop` はコンテナが停止する前にロード
バランサーがトラフィックを流し終える時間を与えます。

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

4 つのレプリカすべてが spot ノードに配置されたことを確認します:

```bash
kubectl get po -n eks-111 -l app=spotapp -o wide
NODES=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[*].spec.nodeName}')
for n in $NODES; do
  kubectl get node "$n" -L karpenter.sh/capacity-type --no-headers
done
```

Karpenter が新しい EC2 ノードを立ち上げるのにおよそ 60-90 秒かかるため、最初は Pod が
`Pending` のままになることがあります。先に進む前に `rollout status` を待ちます。

## タスク 3. アーティファクト:spot ノードと NodePool の多様化

capacity-type と instance category のラベルを付けたノードのスナップショット、そして
NodePool `spot-lab` の requirements を保存し、幅広いファミリーのセット(多様化)を
確認します。

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -L karpenter.sh/capacity-type -L karpenter.k8s.aws/instance-category \
  > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt

kubectl get nodepool spot-lab -o yaml \
  | grep -A5 'instance-category' > /var/work/tests/artifacts/3/nodepool.txt
cat /var/work/tests/artifacts/3/nodepool.txt
```

`nodes.txt` には `capacity-type=spot` のノードが少なくとも 1 つあるはずです。
`nodepool.txt` には 3 つの instance category `c`、`m`、`r` が存在するはずです - これが
多様化の要件です:プール spot-lab は 1 つの instance ファミリーに絞られていません。

## タスク 4. `spotapp` に対する PodDisruptionBudget

4 レプリカ中 `minAvailable: 3` は、過剰な voluntary eviction から保護します:

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

## タスク 5. 症状:drain は PDB によってブロックされるが、これは AWS の spot から救ってはくれない

`spotapp` の Pod が少なくとも 1 つあるノードを選び、cordon して drain を試みます。
4 レプリカと `minAvailable: 3` では、PDB は一度に 1 つのレプリカしか eviction を許可
しません(`disruptionsAllowed` は 1 を超えません) - drain は 1 つのレプリカより先には
進みません。

```bash
NODE=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[0].spec.nodeName}')
kubectl cordon "$NODE"
kubectl get pdb spotapp-pdb -n eks-111 -o jsonpath='{.status.disruptionsAllowed}'
echo

# 何が eviction されようとするか、ノード全体を実際に drain せずに確認する
kubectl drain "$NODE" --ignore-daemonsets --dry-run=client
```

症状と PDB の責任範囲の境界の説明をアーティファクトに記録します:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/drain.txt <<'EOF'
ノードは cordon され、drain は eviction API を通じて spotapp の Pod を退去させようと
します。minAvailable: 3 を持つ PDB spotapp-pdb は、一度に 1 つを超えるレプリカの
eviction を許可しません(4 レプリカのとき disruptionsAllowed <= 1):予算を破る
eviction は拒否され、drain は 1 つのレプリカより先には進みません。

重要な境界:PDB は保護するのは voluntary(意図的な)eviction だけです -
kubectl drain、ノードのアップグレード、Karpenter の consolidation。AWS による spot
インスタンスの強制的な取り上げからは保護されません:AWS が 2 分間の通知期限の後に
実際にインスタンスを回収する場合、そのインスタンス上の Pod は PDB に関係なく終了
します。これは Kubernetes の voluntary な操作ではなく、インスタンス自体の
停止だからです。
EOF
cat /var/work/tests/artifacts/5/drain.txt

kubectl uncordon "$NODE"
```

## タスク 6. Karpenter の割り込み処理の確認

Karpenter は割り込みキュー(`interruptionQueue`、このラボとは無関係にモジュール
`eks_v2_karpenter` で設定済み)を通じて spot 割り込みを自ら処理します。コントローラの
ログでこのメカニズムを確認します - worker には `aws sqs list-queues` の権限がない場合
があるため、`kubectl logs` を使います:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i interrupt > /var/work/tests/artifacts/6/interruption.txt

# まだ割り込みイベントがない場合は、メカニズムが存在すること自体を記録する:
if [[ ! -s /var/work/tests/artifacts/6/interruption.txt ]]; then
  echo "no interruption events yet, but Karpenter interruption handling is configured via interruptionQueue" \
    > /var/work/tests/artifacts/6/interruption.txt
fi
cat /var/work/tests/artifacts/6/interruption.txt
```

## クイックチェック

```bash
check_result
```
