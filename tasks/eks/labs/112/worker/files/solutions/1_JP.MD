[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 112 - 参考解答(Fargate:プロファイル、制限、コスト)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl は既にクラスタ向け
に設定されています(kubeconfig はマシン起動時に `aws eks update-kubeconfig` によって組
み立てられます)。namespace `eks-112` 用の Fargate プロファイル `workload` はラボのイ
ンフラストラクチャによって既に作成されています - 学生は namespace とその中のオブジェ
クトを作成するだけで済みます。

## タスク 1. Namespace `eks-112`

```bash
kubectl create namespace eks-112
```

`workload` プロファイルは `namespace = eks-112` にマッチし、`labels` はありません。
そのため namespace 全体がそのまま Fargate に配置されます - この中に例外はありません。

## タスク 2. Fargate 上の Guaranteed Pod `fg-app`

Fargate は `requests` が `limits` と等しい Pod(`Guaranteed` クラス)しか実行しません。
明示的に等しい値を持つ Deployment を作成します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
```

Pod が Fargate ノードに配置されていること(ノード名が `ip-` ではなく `fargate-` で始ま
ること)を確認します:

```bash
kubectl get po -n eks-112 -l app=fg-app -o wide
```

## タスク 3. アーティファクト:実際に割り当てられたキャパシティ

Fargate はリクエストの合計を固定の vCPU/メモリの組み合わせに切り上げ、Kubernetes のコ
ンポーネント(`kubelet`、`kube-proxy`、`containerd`)用に `256 MB` を追加します。実際
に割り当てられたキャパシティは `CapacityProvisioned` アノテーションで確認できます:

```bash
mkdir -p /var/work/tests/artifacts/3
POD=$(kubectl get po -n eks-112 -l app=fg-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n eks-112 \
  -o jsonpath='{.metadata.annotations.CapacityProvisioned}' \
  > /var/work/tests/artifacts/3/capacity.txt
echo >> /var/work/tests/artifacts/3/capacity.txt
cat /var/work/tests/artifacts/3/capacity.txt
```

`500m` の CPU と `1Gi` のメモリのリクエストに `256 MB` の付加分を加えると、Fargate は
最も近い組み合わせを選びます(例えば `0.5vCPU 1GB`、あるいは付加分を加えた後の合計メ
モリが `1 GB` を超える場合は `0.5vCPU 2GB`)。`kubectl describe pod` はまさにこの行を
表示します。

## タスク 4. 症状:privileged Pod が起動しない

Fargate は privileged コンテナ、DaemonSet、hostNetwork/hostPort、hostPath、GPU を厳格
に禁止しています。`eks-112` に privileged Pod を作成してみます:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-privileged
  namespace: eks-112
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
    securityContext:
      privileged: true
EOF

kubectl get po fg-privileged -n eks-112
kubectl describe po fg-privileged -n eks-112 | sed -n '/Events/,$p'
```

この Pod は `Running` に到達しません:Fargate は admission(准入)の段階で privileged
コンテナを拒否し、これは Pod の events で確認できます。この説明をアーティファクトに保
存します:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/privileged.txt <<'EOF'
Pod fg-privileged は privileged: true をリクエストしているため起動しません。Fargate は
privileged コンテナをサポートしていません。これは DaemonSet、hostNetwork/hostPort、
hostPath、GPU と並ぶ、このモードの厳格な制限の 1 つです。このエラーは、リソース不足
による通常の Pending とは異なり、Pod の events では admission の拒否として表示されま
す。
EOF
cat /var/work/tests/artifacts/4/privileged.txt
```

後続のチェックの妨げにならないよう、この Pod を削除しておきます:

```bash
kubectl delete pod fg-privileged -n eks-112
```

## タスク 5. エフェメラルディスクを 30Gi に拡張

デフォルトでは Fargate は `20 GiB` のエフェメラルディスクを提供し、`resources` の
`ephemeral-storage` を使って最大 `175 GiB` まで拡張できます(requests は limits と等し
くなければならず、Pod は Guaranteed のままです)。`fg-app` を更新します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
kubectl get po -n eks-112 -l app=fg-app -o wide
```

Pod は正常に起動します:`30Gi` は許可されている `175 GiB` の範囲内であり、`requests ==
limits` の要件も満たされています。

## タスク 6. コスト構造:Fargate 対 node group

重要な違いは課金単位です。Fargate は特定の Pod の vCPU とメモリに対して、その稼働時間
だけ課金します。node group は、その負荷にかかわらず EC2 インスタンス全体に対して課金
します。このアーティファクトの自動チェックは、`vCPU` の隣にある単
語 `pod` を探すので、以下のアーティファクトには両方を含めています:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/costmodel.txt <<'EOF'
Fargate は pod 自身の vCPU とメモリに対して、それが実際に稼働している時間だけ課
金します。pod が稼働していなければ費用は発生せず、アイドル状態のキャパシティに対して
余分に支払うことはありません。一方 node group は、インスタンス全体に対して課金しま
す。pod の間でノードがアイドル状態になっていたり、十分に利用されていない時間についても
料金が発生します。リソース単位あたりで見ると、Fargate は通常、node group のノード上の
同等のリソースよりも高価です。そのため最終的な経済性は利用率に依存します。高く予測可能
な負荷であれば node group の方が安く、変動が大きく予測しにくい需要であれば Fargate の
方がアイドルインスタンスへの余分な支払いを避けられます。
EOF
cat /var/work/tests/artifacts/6/costmodel.txt
```

## クイックチェック

```bash
check_result
```
