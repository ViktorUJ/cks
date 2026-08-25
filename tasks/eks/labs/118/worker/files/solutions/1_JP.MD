[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 118 - 参考解答（GitOps: Argo CD、drift と self-heal、sync waves）

すべてのコマンドは worker マシン上で SSH 経由で実行します。kubectl は
すでにクラスター用に設定されています（kubeconfig はマシン起動時に
`aws eks update-kubeconfig` で組み立てられます）。

## タスク 1. Helm による Argo CD のインストール

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd

kubectl rollout status deployment/argocd-server -n argocd
```

サーバーが起動したことを確認します:

```bash
kubectl get deploy argocd-server -n argocd
kubectl get pods -n argocd
```

## タスク 2. Namespace `eks-118` と Application オブジェクト

```bash
kubectl create namespace eks-118
```

Application は Git のソース（コース自体のリポジトリ、ブランチ `AG-155`、
パス `tasks/eks/labs/118/gitops-demo`）と、対象のクラスターおよび
namespace `eks-118` を結びつけます。`selfHeal: true` は手動での変更を
ロールバックし、`prune: true` は Git から取り除かれたリソースをクラス
ターから削除します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ViktorUJ/cks.git
    targetRevision: AG-155
    path: tasks/eks/labs/118/gitops-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: eks-118
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF
```

Application が `Synced` と `Healthy` に達するまで待ちます:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}'
echo
```

両方のコマンドは最終的にそれぞれ `Synced` と `Healthy` を返すはずです
（Argo CD は Git をポーリングし、マニフェストを自動的に適用します。
auto-sync はデフォルトで有効になっています）。

## タスク 3. オブジェクトが実際に適用されたことの確認

```bash
kubectl get deployment demo-app -n eks-118
kubectl get configmap demo-config -n eks-118 -o yaml
kubectl rollout status deployment/demo-app -n eks-118
```

Deployment `demo-app`（image `viktoruj/ping_pong:latest`、2 レプリカ）と
ConfigMap `demo-config` は、学生の手動の `kubectl apply` ではなく、
Argo CD を通じて Git から来たものです。

## タスク 4. drift と self-heal

実際に動いているクラスターでしか見えない重要な点があります。`selfHeal`
が有効な状態では、コントローラーが数秒で drift をロールバックしてしまう
ため、`OutOfSync` を目で捉えることは実質的に不可能です（手動の
`kubectl scale` は最初の `kubectl get application` の前にすらロール
バックされてしまいます）。そのため drift は二段階で示します。まず
自己修復を無効にし、`OutOfSync` を捉え、それから自己修復を再度有効にして
ロールバックを観察します。

ステップ 1. `selfHeal` だけを無効にし、`prune` は有効のままにします:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false,"prune":true}}}}'
```

ステップ 2. Git を経由せずに実際の状態を壊し、drift を記録します:

```bash
kubectl scale deployment demo-app -n eks-118 --replicas=5

for i in $(seq 1 20); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  [[ "$status" == "OutOfSync" ]] && break
  sleep 3
done

mkdir -p /var/work/tests/artifacts/4
{
  echo "=== selfHeal=false の場合の drift（手動の kubectl scale --replicas=5）==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} > /var/work/tests/artifacts/4/drift.txt
```

self-heal がない状態では Application は `OutOfSync` のままです。
auto-sync は Git の変更に反応しますが、クラスター内部で生じた差分を
修復するのはまさに `selfHeal` です。

ステップ 3. `selfHeal` を再度有効にし、Git の状態への自動ロールバックを
観察します:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'

for i in $(seq 1 40); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  replicas=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.spec.replicas}')
  [[ "$status" == "Synced" ]] && [[ "$replicas" == "2" ]] && break
  sleep 3
done

{
  echo "=== selfHeal を再度有効にした後: Git の状態へのロールバック ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} >> /var/work/tests/artifacts/4/drift.txt

cat /var/work/tests/artifacts/4/drift.txt
```

このファイルには `OutOfSync`（自己修復なしでの drift）と `Synced`
（self-heal が Git の状態を戻した）の両方が含まれています。最後に
`replicas` は再び `2` になります。

## タスク 5. Sync waves: 適用の順序

`gitops-demo/configmap.yaml` にはアノテーション
`argocd.argoproj.io/sync-wave: "0"` が、`gitops-demo/deployment.yaml`
には `argocd.argoproj.io/sync-wave: "1"` が付いています。より小さい
wave 番号が先に適用されるため、ConfigMap は必ず Deployment より前に
クラスターに入ります（これは Deployment が `envFrom` を通じて
ConfigMap から値を読み込む場合に重要です）:

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
kubectl get deployment demo-app -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
```

異なる wave にあるにもかかわらず、両方のオブジェクトが最終的に同期
されていることを確認します:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.resources}' | head -c 400
```

## タスク 6. prune が削除するものとしないもの: リソースの所有権

`prune: true` はタスク 2 からすでに有効になっています。`gitops-demo/`
には存在しない ConfigMap を `eks-118` に手動で作成します。誰かが Git
の外で作成したかのような、普通の手動オブジェクトです:

```bash
kubectl create configmap manual-extra -n eks-118 --from-literal=note=manual

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

sleep 30
kubectl get configmap manual-extra -n eks-118
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'; echo
```

予想外の結果です: `prune=true` が有効なのに、`manual-extra` は
**削除されず**、Application は `Synced` のままです。理由は所有権の
モデルにあります。Argo CD はアプリケーションに属していると印付けられた
オブジェクトだけを管理します。Argo CD 3.x ではこれは
`argocd.argoproj.io/tracking-id` アノテーションです。Git から来た
オブジェクトがどう印付けられているか確認してみます:

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'; echo
# demo-app:/ConfigMap:eks-118/demo-config
```

手動のオブジェクトにはこの印がないため、Argo CD にとって無関係
（orphaned）であり、prune の対象範囲に入りません。この観察結果を
記録します:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== tracking アノテーションがない場合、prune はオブジェクトに触れない ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "sync: $(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')"
} > /var/work/tests/artifacts/6/prune.txt
```

今度は ConfigMap をアプリケーションに属するものとして印付けます。
値の形式は `<app>:<group>/<Kind>:<namespace>/<name>` で、core リソース
の場合 group は空です:

```bash
kubectl annotate configmap manual-extra -n eks-118 \
  'argocd.argoproj.io/tracking-id=demo-app:/ConfigMap:eks-118/manual-extra' --overwrite

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

for i in $(seq 1 20); do
  kubectl get configmap manual-extra -n eks-118 >/dev/null 2>&1 || break
  sleep 5
done

kubectl get configmap manual-extra -n eks-118 2>&1
```

これでこのオブジェクトはアプリケーションに追跡されるようになり、
Git には存在しないため、prune がそれを削除します。一方
`demo-config` と `demo-app` は `gitops-demo/` に記述されているため
そのまま残ります:

```bash
{
  echo "=== tracking アノテーションを追加した後、prune がオブジェクトを削除した ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 2>&1 | tail -n1)"
  echo "demo-config: $(kubectl get configmap demo-config -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "demo-app: $(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.metadata.name}')"
  echo
  echo "prune はアプリケーションに追跡（tracked）されていて Git に存在しない"
  echo "リソースだけを取り除きます。tracking アノテーションのない手動の"
  echo "オブジェクトは Argo CD にとって無関係（orphaned）であり、prune の"
  echo "対象にはなりません - これが最初に観察された結果です。demo-config と"
  echo "demo-app は gitops-demo/ に記述されており、Argo CD がそれらを同期"
  echo "し続けるため、そのまま残りました。"
} >> /var/work/tests/artifacts/6/prune.txt

cat /var/work/tests/artifacts/6/prune.txt
```

## タスク 7. 診断: sync status と health status - 二つの異なる軸

auto-sync を無効にします（同じブロックにある self-heal も一緒に）。
これにより、すぐにロールバックされることなく落ち着いて症状を
発生させることができます:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

コンテナの readinessProbe をクラスター内で直接壊します。注意: 学習用
イメージ `ping_pong` はどんなパスにも `200` を返すため、「存在しない
URL」への probe は問題なく通過してしまい、症状が出ません。代わりに
probe を閉じたポート `9999` に向けます。そこには誰も listen して
いません:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe","value":{
    "httpGet": {"path": "/healthz", "port": 9999},
    "initialDelaySeconds": 2,
    "periodSeconds": 3,
    "failureThreshold": 2
  }}
]'
```

待ってからステータスを記録します。sync と health は独立した軸です:
sync は Git と実際の状態との差分を反映し、health はリソースの実際の
健全性（pod の準備状況など）です:

```bash
sleep 30
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== readinessProbe を手動で変更した後に観察されたステータス ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  echo
  echo "=== 説明: sync status と health status は異なる軸である ==="
  echo "Sync status（Synced/OutOfSync）はオブジェクトの実際の状態を Git に"
  echo "記録されている内容と比較します: 一致していれば Synced、ずれていれば"
  echo "OutOfSync です。"
  echo "Health status（Healthy/Progressing/Degraded/Missing）はリソースの"
  echo "今この瞬間の実際の健全性です: pod が準備できているか、"
  echo "readiness/liveness probe が通過したかどうかです。"
  echo "閉じたポートへの probe のせいで、新しい demo-app の pod は readiness"
  echo "を通過できず、health は Progressing になります（progressDeadlineSeconds"
  echo "が過ぎると Degraded になります）。その一方で sync は Synced のまま"
  echo "です。理由: readinessProbe フィールドは Git のマニフェストに記述"
  echo "されていないため、手動で追加されたフィールドは差分にカウントされ"
  echo "ません。一方 replicas は Git にあるため、その手動変更が task 4 で"
  echo "OutOfSync を引き起こしました。"
  echo "これは両方の軸が独立して計算されることを証明しています: Synced と"
  echo "Degraded/Progressing に同時になり得るのと同様に、OutOfSync と"
  echo "Healthy にも同時になり得ます。"
} > /var/work/tests/artifacts/7/health.txt

cat /var/work/tests/artifacts/7/health.txt
```

auto-sync と self-heal を再度有効にします:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'
```

重要な観察です: self-heal はこの故障を**修復しません**。Argo CD に
とって Git との差分がない（`sync=Synced`）ため、修復すべきものが
ないのです。その一方で `health` は正直に `Progressing`、続いて
`Degraded` を示します。実用的な結論はこうです: `Synced` はクラスター
が Git とバイト単位で一致していることを意味しません。マニフェストに
ないフィールドは運用者の責任のままです。そのため probe を手動で
取り除きます:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'

for i in $(seq 1 20); do
  health=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}')
  ready=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.status.readyReplicas}')
  [[ "$health" == "Healthy" ]] && [[ "$ready" == "2" ]] && break
  sleep 5
done

kubectl get application demo-app -n argocd \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
echo
```

## クイックチェック

```bash
check_result
```
