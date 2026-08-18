[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 101 - 参考解答(コードとしてのクラスタ:アクセス、コンピュート、ネットワーク、AMI)

すべてのコマンドはワーカーマシン(worker)上で SSH 経由で実行します。kubectl はすでに
クラスタ向けに設定されています(kubeconfig はマシン起動時に `aws eks update-kubeconfig`
で組み立てられます)。

## タスク 1。Namespace `eks-101`

```bash
kubectl create namespace eks-101
```

## タスク 2。Deployment `web`(viktoruj/ping_pong、3 レプリカ)を EC2 ノード上に

システム Pod(kube-system、karpenter)は Fargate 上で動き、通常の namespace にある Pod
は Karpenter が立ち上げる EC2 ノードにスケジュールされます。そのため `eks-101` の
Deployment は自動的に EC2 に配置されます:

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3 -n eks-101
kubectl rollout status deployment/web -n eks-101
```

Pod が Fargate 上にないことを確認します(ノード名が `fargate-` ではなく `ip-` で始まる):

```bash
kubectl get po -n eks-101 -l app=web -o wide
```

理由:Fargate は、Pod の namespace が Fargate profile に一致する場合にのみ Pod を実行し
ます。このラボでは profile は `kube-system` と `karpenter` に対して設定されており、
`eks-101` 用のものはないため、`eks-101` のワークロードは Karpenter(EC2)が引き受けます。
この説明はタスク 7 で記録します。

## タスク 3。アーティファクト:システムノードとワーカーノードの分離

どれが Fargate でどれが EC2 かを示すノード一覧を保存します:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -o wide > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt
```

ファイルには `fargate-...` ノード(システム Pod)と `ip-...` ノード(Karpenter のワー
カーノード)の両方が含まれるはずです。これはまさに第 9 章のコンピュートの分離です。

## タスク 4。アーティファクト:VPC の CIDR から取得した Pod の IP

VPC CNI は、ノードのサブネット(`10.10.15.0/24` または `10.10.16.0/24`)、つまり VPC
`10.10.0.0/16` からルーティング可能なアドレスを Pod に割り当てます:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].status.podIP}' \
  > /var/work/tests/artifacts/4/podip.txt
echo >> /var/work/tests/artifacts/4/podip.txt
cat /var/work/tests/artifacts/4/podip.txt
```

VPC CNI をより深く理解するために、Pod のアドレスをプライベートサブネットの CIDR と比較
してみてください(Pod は自分のノードのサブネットから IP を取得しています):

```bash
VPC=$(aws eks describe-cluster --name "$(kubectl config current-context | sed 's|.*/||')" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[CidrBlock,AvailabilityZone]' --output table
```

## タスク 5。アーティファクト:ワーカーノードの AMI(AL2023)

任意のワーカー(EC2)ノードの OS イメージを確認します。デフォルトの NodePool は
`al2023@latest` 上に構築されているため、Amazon Linux 2023 です:

```bash
mkdir -p /var/work/tests/artifacts/5
NODE=$(kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.status.nodeInfo.osImage}' \
  > /var/work/tests/artifacts/5/ami.txt
echo >> /var/work/tests/artifacts/5/ami.txt
cat /var/work/tests/artifacts/5/ami.txt
```

## タスク 6。Deployment `batch`(CPU request 付きの 6 レプリカ) - Karpenter によるスケーリング

明示的な requests を持つワークロードは、Karpenter にコンピュートリソースを追加させます。
CPU request を付けて deployment を作成し、すべてのレプリカが準備完了になるまで待ちます:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch
  namespace: eks-101
spec:
  replicas: 6
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/batch -n eks-101
```

Karpenter がノードを立ち上げる様子は次のように観察できます:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type=default -o wide
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | tail -n 20
```

## タスク 7。責任の境界:症状と説明

意図的に、存在しない場所で Fargate を要求します。Pod は `Pending` のまま止まるはずです:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-probe
  namespace: eks-101
spec:
  nodeSelector:
    eks.amazonaws.com/compute-type: fargate
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get po fg-probe -n eks-101 -o wide
kubectl describe po fg-probe -n eks-101 | sed -n '/Events/,$p'
# namespace 全体のイベントを時刻順に確認する - スケジューリング失敗を診断する SRE のスキル
kubectl get events -n eks-101 --sort-by='.metadata.creationTimestamp'
```

Pod は `Pending` のままです:`eks-101` には Fargate profile がないため、EKS は Pod を
Fargate にスケジュールしません。また Karpenter の EC2 ノードは
`eks.amazonaws.com/compute-type: fargate` というラベルを持たないため、Karpenter も
EC2 ノードを作成しません。この要求を満たせる存在はどこにもありません。

説明をアーティファクトとして保存します:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/whyfargate.txt <<'EOF'
web と batch の Pod は Fargate ではなく Karpenter の EC2 ノードに配置された。Fargate は
Pod の namespace が profile に一致する場合にのみ Pod を実行する。クラスタには
kube-system と karpenter 用の profile はあるが、eks-101 用の profile はない。

fg-probe が Pending のまま止まったのは、明示的に Fargate を要求している(nodeSelector
eks.amazonaws.com/compute-type: fargate)ためだが、eks-101 用の profile はなく、
Karpenter の EC2 ノードもそのラベルを持っていない。Fargate も Karpenter もこの要求を
満たすことができない。
EOF
cat /var/work/tests/artifacts/7/whyfargate.txt
```

責任の境界が明確に見えてきます:どの namespace が Fargate に乗るかは(第 9 章の
Fargate profile を通じて)あなた自身が決めることであり、EKS が「独自に」決めるもの
ではありません。

## クイックチェック

```bash
check_result
```
