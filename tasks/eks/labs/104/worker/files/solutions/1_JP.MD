[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 104 - 参考解答(workload identity: IRSA と Pod Identity)

すべてのコマンドはワーカーマシン(worker)上で SSH を通じて実行します。kubectl は既に
クラスタ向けに設定されており、terraform は既に S3 バケット、Secrets Manager のシークレ
ット、両方の IAM ロールを作成しています - その名前と ARN はヒントファイル
`/home/ubuntu/lab104_hints.txt` にあります。

```bash
cat ~/lab104_hints.txt
```

以下の例ではこのファイルの変数を使います - 自分の値に置き換えるか、セッションの最初に
エクスポートしてください:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab104_hints.txt | awk '{print $3}')
export SECRET_NAME=$(grep '^secret_name' ~/lab104_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export POD_IDENTITY_ROLE_ARN=$(grep '^pod_identity_role_arn' ~/lab104_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab104_hints.txt | awk '{print $3}')
```

## タスク 1. Namespace `eks-104`

```bash
kubectl create namespace eks-104
```

## タスク 2. IRSA のアノテーションを持つ ServiceAccount

ロール `irsa_role_arn` は terraform によってすでに作成されており、ちょうどこの
`ServiceAccount`(`system:serviceaccount:eks-104:s3-reader-irsa` - 第 16 章)を信頼する
trust policy を持っています。アノテーション付きで SA を作成します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: s3-reader-irsa
  namespace: eks-104
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

kubectl get sa s3-reader-irsa -n eks-104 -o yaml
```

## タスク 3. IRSA を持つ Pod: アイデンティティの確認

この SA を使う Pod を作成します。Pod Identity Webhook は Pod の起動時に
`AWS_ROLE_ARN` と `AWS_WEB_IDENTITY_TOKEN_FILE` の変数(第 16 章)を注入します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-104
spec:
  serviceAccountName: s3-reader-irsa
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-104 --timeout=120s
```

Pod 内の SDK がノードのロールではなく web identity を通じてクレデンシャルを取得したこ
とを確認します:

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl exec irsa-app -n eks-104 -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/3/irsa_identity.txt
cat /var/work/tests/artifacts/3/irsa_identity.txt
```

出力の `Arn` は `arn:aws:sts::<account>:assumed-role/<prefix>-irsa-role/...` のような形
になるはずです - これは Pod がノードのロールではなく IRSA のロールで動いていることを
証明しています。

## タスク 4. IRSA を通じた S3 からのオブジェクトの読み取り

`irsa` のロールはこの具体的なバケットに対して `s3:ListBucket` と `s3:GetObject` のみを
持っています(第 16 章、least privilege)。terraform がバケットに置いたオブジェクトを
読み取ります:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec irsa-app -n eks-104 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" - \
  > /var/work/tests/artifacts/4/s3_read.txt
cat /var/work/tests/artifacts/4/s3_read.txt
```

ファイルには `hello from s3` という行があるはずです - モジュール
`eks_v2_workload_identity_demo` が置いたオブジェクトの内容です。

## タスク 5. Pod Identity のアソシエーション

IRSA とは異なり、Pod Identity では SA へのアノテーションは不要です - `namespace + SA ->
ロール` の結びつけは Kubernetes ではなく EKS の API に存在します(第 17 章)。SA とアソ
シエーションを作成します:

```bash
kubectl create serviceaccount secret-reader-podid -n eks-104

aws eks create-pod-identity-association \
  --cluster-name "${CLUSTER_NAME}" \
  --namespace eks-104 \
  --service-account secret-reader-podid \
  --role-arn "${POD_IDENTITY_ROLE_ARN}"

mkdir -p /var/work/tests/artifacts/5
aws eks list-pod-identity-associations --cluster-name "${CLUSTER_NAME}" --namespace eks-104 \
  > /var/work/tests/artifacts/5/association.txt
cat /var/work/tests/artifacts/5/association.txt
```

## タスク 6. Pod Identity を持つ Pod: ノードのロールの代わりにシークレット

SA `secret-reader-podid` を持つ Pod を作成します。エージェント
`eks-pod-identity-agent`(このラボでは既に managed addon としてインストール済み)は、
ローカルの endpoint `169.254.170.23` を通じて `pod_identity_role_arn` のロールのクレデ
ンシャルを渡します(第 17 章):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: podid-app
  namespace: eks-104
spec:
  serviceAccountName: secret-reader-podid
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/podid-app -n eks-104 --timeout=120s
```

シークレットを読み取り、アイデンティティを 1 つのコマンドで確認します:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "--- caller identity ---"
  kubectl exec podid-app -n eks-104 -- aws sts get-caller-identity
  echo "--- secret value ---"
  kubectl exec podid-app -n eks-104 -- aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" --query SecretString --output text
} > /var/work/tests/artifacts/6/secret_read.txt
cat /var/work/tests/artifacts/6/secret_read.txt
```

`get-caller-identity` の `Arn` は `assumed-role/<prefix>-pod-identity-role/...` を示し、
シークレットの値は terraform が Secrets Manager に置いた `username`/`password`
(`demo`/`demo123`)フィールドを持つ JSON です。

## タスク 7. 症状: ノードのロールはバケットへのアクセス権を持たない

IRSA も Pod Identity も紐付いて**いない** Pod を作成します - これはノードのロールの
権限だけを引き継ぎます(第 16 章、16.1 節: 「ノードにロールを渡すと、その権限がすべての
Pod に漏れる」は反対方向にも成り立ちます。ノードのロールはアプリケーション向けの権限を
そもそも一切持っていません):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: plain-app
  namespace: eks-104
spec:
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/plain-app -n eks-104 --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl exec plain-app -n eks-104 -- aws s3 ls "s3://${BUCKET_NAME}/" \
  > /var/work/tests/artifacts/7/node_role_denied.txt 2>&1
cat /var/work/tests/artifacts/7/node_role_denied.txt
```

コマンドは `AccessDenied`(または `is not authorized to perform`)エラーで終わるはずで
す - ノードのロールはこのバケットに対する `s3:*` を持っておらず、システムコンポーネン
ト(ECR からの pull、CNI の動作)の権限しか持っていません。これは違いを分かりやすく示
しています: IRSA も Pod Identity もない場合、Pod はノードのロールが持っているものしか
得られず、「アカウントのどこかで設定されているすべて」を得るわけではありません。

## クイックチェック

```bash
check_result
```
