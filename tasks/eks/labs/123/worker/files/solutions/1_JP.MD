[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 123 - 参考解答(Karpenter:NodePool、consolidation、StatefulSet)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl は
すでにクラスタ用に設定されています(kubeconfig はマシン起動時に
`aws eks update-kubeconfig` で組み立てられています)。

## タスク 1. Namespace `eks-123`

```bash
kubectl create namespace eks-123
```

## タスク 2. NodePool、EC2NodeClass、NodeClaim のインベントリ

クラスタにすでに設定されているプールを確認します:デフォルトの `default`
(spot と on-demand)と新しい `stateful`(on-demand のみ、taint
`dedicated=stateful`):

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

出力には `default` と `stateful` という名前の行が含まれているはずです -
これらは 2 つの独立した NodePool で、それぞれが独自の `EC2NodeClass` を
持っています(第 12.2-12.3 章)。

## タスク 3. `stateful` プール上の StatefulSet `db`

`stateful` プールは taint `dedicated=stateful:NoSchedule` で閉じられている
ため、pod には toleration が必要です。このラボの目的にはボリュームは必須では
ありません - 焦点は disruption にあり、EBS にはありません(独自の PVC を
持つ StatefulSet のボリュームは第 23 章で扱います):

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

すべてのレプリカが `stateful` プールに乗ったことを確認します(ノードラベル
`work_type=stateful`):

```bash
kubectl get po -n eks-123 -l app=db -o wide
kubectl get nodes -L work_type
```

## タスク 4. PodDisruptionBudget `db-pdb`

`maxUnavailable: 1` は自発的な排除を止める主なブレーキです。Karpenter は
Eviction API を通じてドレインするため、PDB は一度に複数のレプリカが排除される
ことを許可しません:

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

## タスク 5. 症状:排除の権利がない PDB が consolidation をブロックする

`stateful` プールのノードはすでにリソース利用率が低い状態です:`250m` ずつの
3 つのレプリカが 2 つの `m6g.medium` ノードに分散しており、
`consolidateAfter: 30s` を持つ Karpenter は常にそれらを consolidation しようと
します。負荷を強制する必要はありません - consolidation を妨げているものを
観察するだけです。

重要:`maxUnavailable: 1` の場合、PDB は consolidation をブロックしません。
一度に 1 つの排除を許可し(`ALLOWED DISRUPTIONS=1`)、Karpenter はノードを
1 レプリカずつドレインし、静かに削除します。ブロックが発生するのは、PDB が
排除を一つも許可しない場合だけです。保護を完全なロックダウンまで強化します -
3 レプリカに対して `minAvailable: 3`:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"maxUnavailable":null,"minAvailable":3}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` 列は今 `0` になっています。1-2 分後、プールのノードで
ブロックのイベントが現れます。注意:これは `Unconsolidatable` ではなく、
別の `DisruptionBlocked` です:

```bash
for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $n ==="
  kubectl describe node "$n" | grep -A2 DisruptionBlocked
done
```

期待される行:`Pdb prevents pod evictions (PodDisruptionBudget=[eks-123/db-pdb])`。
コントローラ自体のログは `karpenter` namespace にあります(`kube-system` では
ありません - そこにはアドオンしかなく、Karpenter は Fargate profile 上の
別の release としてデプロイされています):

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i "disrupting node"
```

観察結果を artifact に保存します - `get pdb` の出力と実際のノードイベント:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "症状:排除を一つも許可しないPDBがconsolidationをブロックしている。"
  echo "db-pdbは3レプリカでminAvailable=3まで強化された -> ALLOWED DISRUPTIONS=0。"
  kubectl get pdb db-pdb -n eks-123
  echo
  echo "=== statefulプールのノードイベント ==="
  for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
    kubectl describe node "$n" | grep -E "DisruptionBlocked|Unconsolidatable" | sed "s|^|$n |"
  done
} > /var/work/tests/artifacts/5/consolidation.txt

cat /var/work/tests/artifacts/5/consolidation.txt
```

PDB を動作する状態に戻します。そうしないとタスク 4 は通らず、プールのノードは
永遠に離脱できません:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"minAvailable":null,"maxUnavailable":1}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` は再び `1` になります。運用上の結論:レプリカ数と等しい
`minAvailable`(または `maxUnavailable: 0`)は consolidation だけでなく、
あらゆる drain を止めます - つまりノードの更新やクラスタのアップグレードも
止まります(第 12.6 章、第 40 章)。

## タスク 6. 修正:狙いを定めた `do-not-disrupt`

StatefulSet の正しい保護は 3 つの部分の組み合わせであり(第 12.7 章)、
すべてに対する 1 つのアノテーションではありません。PDB(タスク 4)はすでに
レプリカ単位の排除を提供しています。`stateful` プールの disruption budget
(`eks_karpenter_stateful_vng/terragrunt.hcl` の `nodes: 50%`)はペースを制限
し、Karpenter がプールのすべてのノードを一度に触れないようにします。第三の
部分は `do-not-disrupt` で、現在中断が受け入れられないレプリカだけに狙いを
定めます(例えば `db-0` がリーダーシップや長時間の操作を保持している場合)、
StatefulSet 全体ではありません:

```bash
kubectl annotate pod db-0 -n eks-123 karpenter.sh/do-not-disrupt=true
kubectl get po db-0 db-1 db-2 -n eks-123 \
  -o custom-columns=NAME:.metadata.name,DO_NOT_DISRUPT:'.metadata.annotations.karpenter\.sh/do-not-disrupt'
```

`db-1` と `db-2` にはアノテーションを付けません - そうしないと保護が全面的に
なり、第 12.8 章で説明されているように、consolidation だけでなく drift
(AMI の更新)もブロックしてしまいます。

アノテーションが実際に機能していることは、タスク 5 の PDB と同じメカニズムで
確認できます - Karpenter は `db-0` を保持しているノードに別のイベントを
書き込みます:

```bash
NODE=$(kubectl get po db-0 -n eks-123 -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | grep -A1 'do-not-disrupt'
```

期待される行:`DisruptionBlocked ... Pod has "karpenter.sh/do-not-disrupt"
annotation (Pod=eks-123/db-0)`。つまり、狙いを定めたアノテーションは、保護
されたレプリカを保持するノードの consolidation だけを止め、Karpenter は
プールの他のノードには触れることができます。

説明を artifact に保存します:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/fix.txt <<'EOF'
consolidationの際にStatefulSet dbを正しく保護する方法は、すべてに対する1つの
アノテーションではなく、3つの独立した部分です:

1. PDB db-pdb (maxUnavailable: 1) - レプリカ単位の排除、クォーラムは決して
   失われない。まさにこの値がALLOWED DISRUPTIONS=1を保つ。全面的なロック
   ダウン(3レプリカでminAvailable=3)はALLOWED DISRUPTIONS=0と
   DisruptionBlocked "Pdb prevents pod evictions" イベントをもたらす -
   PDB自体が修正されるまで永遠に(タスク5)。
2. statefulプールのdisruption budget (nodes: 50%) - Karpenterが同時に触れる
   ことができるプールのノードの数を制限し、プール全体を一度に
   consolidationすることを防ぐ。
3. karpenter.sh/do-not-disrupt=trueをdb-0に狙いを定めて設定 - 現在中断が
   受け入れられない具体的なレプリカを保護し、StatefulSet全体を保護するのでは
   ない。

do-not-disruptがdb-0、db-1、db-2に同時に設定されていたら、consolidationだけ
でなくdriftもブロックしてしまう:新しいAMIが出るとき、statefulプールのノード
は更新できなくなり、CVEの負債が積み重なってしまう(第12.8章)。そのため、
このアノテーションは1つのレプリカにだけ設定され、重要な操作が完了したら
取り除かれる。
EOF

cat /var/work/tests/artifacts/6/fix.txt
```

## クイックチェック

```bash
check_result
```
