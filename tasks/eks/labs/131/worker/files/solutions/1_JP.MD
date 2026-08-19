[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ131 - 参考解答（PDBがdrainをブロックする、topology spread、matchLabelKeys）

すべてのコマンドはワークマシン（worker）上でSSH経由で実行します。kubectlはすでにクラス
タ用に設定されています（kubeconfigはマシン起動時に`aws eks update-kubeconfig`で組み立て
られています）。

## タスク1. Namespace `eks-131`

```bash
kubectl create namespace eks-131
```

## タスク2. topology spreadとmatchLabelKeysを持つDeployment `web`

このラボのクラスタは2つのゾーン（`eu-central-1a`と`eu-central-1b`）で動いており、それぞ
れにプライベートサブネット`eks1`/`eks2`があります。これでKarpenterがノードを2つのゾー
ンに分散させ、`topologySpreadConstraints`がpodをそれらに分散させるのに十分です。

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-131
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
          matchLabelKeys:
            - pod-template-hash
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
EOF

kubectl rollout status deployment/web -n eks-131
```

Readyであることとゾーンへの分散を確認します：

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

3つのpodの`NODE`列には少なくとも2つの異なるノードが表示されるはずで、それらのノードは
異なる`topology.kubernetes.io/zone`の値を持つはずです。`matchLabelKeys:
[pod-template-hash]`は最初のこのデプロイにはまだ影響しません（リビジョンが1つだけです）
- タスク6で効いてきます。

## タスク3. 症状：厳しすぎるPDBがdrainをブロックする

3つのレプリカ全員が利用可能であることを要求するPDBを作成します - 予算はどのpodのeviction
も許可しません：

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: eks-131
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
EOF
```

`web`のレプリカのいずれかが乗っているノードを取り、それをdrainしようとします：

```bash
NODE=$(kubectl get pod -n eks-131 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node: $NODE"

mkdir -p /var/work/tests/artifacts/3
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s \
  > /var/work/tests/artifacts/3/drain_blocked.txt 2>&1
echo "drain exit code: $?"
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

コマンドは通りません：`kubectl drain`は`web`のpodに対してeviction APIを呼び出そうとしま
すが、APIは予算違反のため`429`を返し、`--timeout=60s`後にdrainは`global timeout
reached`というエラーで終了します。原因は`minAvailable: 3`のPDB `web-pdb`で、3つの利用
可能なレプリカを要求しているのに実際にちょうど3つしかないため、予算は1つのevictionすら
許可しません：evictionは決して進まず、予算が緩められるまでdrainは止まったままです。

同じアーティファクトに説明を追記します：

```bash
cat >> /var/work/tests/artifacts/3/drain_blocked.txt <<'EOF'

説明：PDB web-pdbはminAvailable: 3を設定しており、これはDeployment webのレプリカ数と
等しい。予算はどのpodのevictionも許可しないため、eviction APIは429を返し、kubectl
drainは止まる/タイムアウトする - これはクラスタのエラーではなく、厳しすぎるPDBの症状
である。
EOF
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

## タスク4. 修正：PDBを緩めてdrainをやり直す

まずノードをサービスに戻します（drainがすでにcordonしています）：

```bash
kubectl uncordon "$NODE"
```

予算を緩めます：これで3つのうち1つのレプリカがevictできるようになります
（`minAvailable: 2`）：

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge -p '{"spec":{"minAvailable":2}}'
kubectl get pdb web-pdb -n eks-131
```

同じノードでdrainをやり直します - 今度は予算が1つのpodのevictionを許可し、drainが通り
ます：

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s \
  > /var/work/tests/artifacts/4/drain_ok.txt 2>&1
echo "drain exit code: $?" >> /var/work/tests/artifacts/4/drain_ok.txt

echo "--- pdb status after drain ---" >> /var/work/tests/artifacts/4/drain_ok.txt
kubectl get pdb web-pdb -n eks-131 >> /var/work/tests/artifacts/4/drain_ok.txt
cat /var/work/tests/artifacts/4/drain_ok.txt
```

ノードをサービスに戻し、3つのレプリカ全部が再びReadyになるのを待ちます（代わりが別の
ノードに立ちました）：

```bash
kubectl uncordon "$NODE"
kubectl rollout status deployment/web -n eks-131
```

## タスク5. unhealthyPodEvictionPolicy: AlwaysAllow

デフォルトでは、PDBは`IfHealthyBudget`ポリシーを使います：不健全な（`Ready`でない）pod
は、それをevictしても予算が違反されない場合にのみevictできます。アプリケーションが壊れ
ていて、podが`CrashLoopBackOff`にはまっている場合、そのpod自体が予算の計算をブロックし、
drainを永遠に妨げることがあります。`AlwaysAllow`はこのブロックを取り除きます：不健全な
podは常にevictでき、健全なpodは予算によって保護されたままです。

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge \
  -p '{"spec":{"unhealthyPodEvictionPolicy":"AlwaysAllow"}}'

kubectl get pdb web-pdb -n eks-131 -o jsonpath='{.spec.unhealthyPodEvictionPolicy}'
echo
```

説明をアーティファクトに保存します：

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/unhealthy_policy.txt <<'EOF'
unhealthyPodEvictionPolicy: AlwaysAllowをweb-pdbに追加した。

デフォルト（IfHealthyBudget）では、currentHealthyがdesiredHealthyを下回らない場合にの
み不健全なpodがevictされる。そのため、CrashLoopBackOffに陥ったpodはそれ自体を予算の一
部として数えてしまい、アプリケーションが既に動作していなくてもdrainを永久にブロックし
かねない。

AlwaysAllowは予算に関係なく不健全なpodのevictionを許可する：CrashLoopBackOffに陥った
壊れたpodはもはやdrainを引き留めず、健全なレプリカはPDBによって保護されたままである。
EOF
cat /var/work/tests/artifacts/5/unhealthy_policy.txt
```

## タスク6. Rolling update：matchLabelKeysが古いpodに分散を妨げさせない

Deploymentを更新して新しいリビジョン（新しい`pod-template-hash`）が出るようにします：
環境変数を追加します。古いpodと新しいpodは共通のラベル`app: web`を持っていますが、
`topologySpreadConstraints`の`matchLabelKeys: [pod-template-hash]`により、skewは自分自
身のリビジョンの中でだけ数えられるため、新しいpodは古いレプリカにブロックされません。

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl set env deployment/web -n eks-131 RELEASE=v2

kubectl rollout status deployment/web -n eks-131 --timeout=180s \
  | tee /var/work/tests/artifacts/6/rollout.txt
```

`Pending`が詰まったpodがないこと、そして更新が実際に適用されたことを確認します：

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get deploy web -n eks-131 \
  -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}'
echo
```

`matchLabelKeys: [pod-template-hash]`がなければ、古いpodも新しいpodも共通のラベル
`app: web`を持つため、両方がskewの計算に参加してしまいます。これがあると、スケジューラ
はセレクタにリビジョンラベルを追加し、分布を自分自身のリビジョンの中でだけ数えます。

自分で確かめる価値のある公平な補足であり、そのまま信じるべきものではありません。この
テスト環境では、`matchLabelKeys`がなくてもrolloutは成功します - 実験で確認済みです：
同じトポロジーを持つがこのフィールドを持たない2番目のDeploymentが、`maxUnavailable: 0`
と`maxSurge: 1`で同じ時間内に更新され、`Pending`は5秒未満しか続かず、skewによるブロック
ではなく通常のスケジューラの待機でした。理由は単純です：3つのレプリカが2つのゾーンに
あると2対1の分散になり、追加のpodは常にpodが少ないほうのゾーンに収まり、ノードに空きが
なければKarpenterがもう1つノードを立ち上げます。

差が本当に現れるのは：固定的なノード群で余剰キャパシティがなく、ゾーンが2つより多く、
古いリビジョンの分散が不均等な場合です。そのとき、両方のリビジョンを同時に数えたskewは
新しいpodに許可されるゾーンを残さず、古いレプリカが取り除かれるのを待つことになります -
大きなノード群では、これが分かりにくい`Pending`を伴う遅いrolloutに変わります。だからこ
そ`matchLabelKeys`はインシデントの後ではなく、事前に設定するのです。今実際に確認する結
果は、新しいリビジョンが`maxSkew: 1`の範囲内でゾーンに分散したままであることです：

```bash
HASH=$(kubectl get po -n eks-131 -l app=web \
  -o jsonpath='{.items[0].metadata.labels.pod-template-hash}')
for n in $(kubectl get po -n eks-131 -l app=web,pod-template-hash="$HASH" \
    -o jsonpath='{.items[*].spec.nodeName}'); do
  kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}'
done | sort | uniq -c
```

## 簡易チェック

```bash
check_result
```
