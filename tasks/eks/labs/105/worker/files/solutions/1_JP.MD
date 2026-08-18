[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 105 - 参考解答(シークレット: KMS envelope encryption、External Secrets)

すべてのコマンドは worker マシン上で SSH 経由で実行します。kubectl はすでにクラスターに
向けて設定済みで、terraform はすでに Secrets Manager のシークレットと ESO コントローラ用
の IRSA ロールを作成しています - それらの名前と ARN はヒントファイル
`/home/ubuntu/lab105_hints.txt` にあります。

```bash
cat ~/lab105_hints.txt
```

以降のコマンドで使うヒントファイルからの変数:

```bash
export SECRET_NAME=$(grep '^secret_name' ~/lab105_hints.txt | awk '{print $3}')
export ROLE_ARN=$(grep '^role_arn' ~/lab105_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab105_hints.txt | awk '{print $3}')
```

## 課題1. Namespace `eks-105`

```bash
kubectl create namespace eks-105
```

## 課題2. レイヤー 1: KMS envelope encryption の確認

Kubernetes 1.28 以降、EKS はあなたが何もしなくても、すべての API オブジェクト(`Secret`
を含む)を AWS のキーでデフォルトで暗号化します。クラスターの暗号化設定を確認します:

```bash
mkdir -p /var/work/tests/artifacts/2
aws eks describe-cluster --name "${CLUSTER_NAME}" --query 'cluster.encryptionConfig' \
  > /var/work/tests/artifacts/2/encryption_config.txt
cat /var/work/tests/artifacts/2/encryption_config.txt
```

出力のリスト要素には `"resources": ["secrets"]` が含まれています - これがレイヤー 1
(etcd 内でのシークレットの envelope encryption)が有効であることの裏付けです。AWS が
所有するキーの代わりに独自の customer managed key(CMK)が必要な場合、それは別のコマンド
`aws eks associate-encryption-config` で行いますが、独自の CMK を有効にすることはできても
暗号化を無効にすることはできません(これは不可逆な操作です)、そのためここでは AWS の
デフォルトキーのままにしておきます。

## 課題3. External Secrets Operator の Helm によるインストール

ロール `role_arn` は terraform によってすでに作成されており、trust policy は
`external-secrets` namespace の SA `external-secrets` にだけ信頼を与えています(第 16 章、
IRSA)。ESO を Helm でインストールし、すぐに ServiceAccount へのアノテーションでロールを
結び付けます:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets --create-namespace \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${ROLE_ARN}"

kubectl rollout status deployment/external-secrets -n external-secrets
kubectl get pods -n external-secrets
```

アノテーションがコントローラの SA に設定されたことを確認します:

```bash
kubectl get sa external-secrets -n external-secrets -o yaml | grep -A1 annotations
```

## 課題4. SecretStore と ExternalSecret

`SecretStore`(namespace スコープ - コマンドごとの分離、第 18.5 章)を作成し、続いて
terraform 由来のデモ用シークレットを参照する `ExternalSecret` を作成します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-sm
  namespace: eks-105
spec:
  provider:
    aws:
      service: SecretsManager
      region: eu-central-1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: db-credentials
  namespace: eks-105
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: aws-sm
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: ${SECRET_NAME}
        property: password
EOF
```

同期を待ち、ネイティブな `Secret` を確認します:

```bash
kubectl wait --for=jsonpath='{.status.conditions[0].reason}'=SecretSynced \
  externalsecret/db-credentials -n eks-105 --timeout=120s

kubectl get externalsecret db-credentials -n eks-105
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

値は terraform が Secrets Manager に入れたパスワード(`S3cr3tPass123`)と一致するはずです。
`refreshInterval: 1m` は意図的に小さめの値にしています - 課題6で、AWS 上のシークレットを
手動で変更した後の再同期をすぐに確認する必要があるためです。

## 課題5. ボリュームを使う Pod: 更新に強い同期パス

`Secret` を env ではなくボリュームとして(volumeMount)マウントします - 第 18.5 章が推奨
する通り、Pod を再作成せずに更新される必要がある値にはこの方法を使います(`Secret` が
変更されると kubelet が自身でボリューム内のファイルを更新します):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: vol-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    volumeMounts:
    - name: db-creds
      mountPath: /etc/db-creds
      readOnly: true
  volumes:
  - name: db-creds
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/vol-reader -n eks-105 --timeout=120s
```

ボリューム内のファイルから値を読み取ります:

```bash
mkdir -p /var/work/tests/artifacts/5
kubectl exec vol-reader -n eks-105 -- cat /etc/db-creds/password \
  > /var/work/tests/artifacts/5/volume_password.txt
echo >> /var/work/tests/artifacts/5/volume_password.txt
cat /var/work/tests/artifacts/5/volume_password.txt
```

## 課題6. env を使う Pod: 値が古くなる症状

同じ `Secret` を、今度は環境変数経由で読み取る 2 つ目の Pod を作成します:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: env-reader
  namespace: eks-105
spec:
  containers:
  - name: app
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
    env:
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
EOF

kubectl wait --for=condition=Ready pod/env-reader -n eks-105 --timeout=120s
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Secrets Manager 上で直接(Kubernetes 経由ではなく)シークレットの値を変更します:

```bash
aws secretsmanager put-secret-value --secret-id "${SECRET_NAME}" \
  --secret-string '{"username":"appuser","password":"RotatedPass456"}'
```

`refreshInterval`(課題4で `1m` に設定)プラス余裕を待ち、ESO がネイティブな `Secret` を
再同期したことを確認します:

```bash
sleep 90
kubectl get secret db-credentials -n eks-105 -o jsonpath='{.data.password}' | base64 -d
echo
```

`Secret` の値はすでに新しい値(`RotatedPass456`)です - ESO は自分の仕事をしました。今度は
ローテーション前に作成された env を使う Pod を見てみます:

```bash
kubectl exec env-reader -n eks-105 -- printenv DB_PASSWORD
```

Pod は依然として古い値(`S3cr3tPass123`)を表示します。理由: コンテナの環境変数はプロセス
起動時に固定されるため、etcd 内の `Secret` の更新はそれらに影響しません - env 経由で新しい
値を受け取るには Pod を再作成する必要があります(Deployment なら `kubectl rollout
restart`、単独の Pod なら手動での削除と再作成)。これは ESO のバグではなく、Kubernetes に
おける env の仕様上の特徴です - Pod を再作成せずに kubelet がディスク上で更新するボリューム
(課題5)とは異なります。

観察結果をアーティファクトとして保存します:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/rotation.txt <<'EOF'
Secrets Manager での put-secret-value と ExternalSecret の再同期の後、etcd 内のネイティブな
Secret db-credentials は新しいパスワード値に更新された - ESO は正常に動作した。

Pod env-reader は env(secretKeyRef)経由でパスワードを読み取るが、コンテナの環境変数は
プロセス起動時に一度だけ固定される。env の値は、Pod を再作成しない限り Secret の変更後も
更新されない - これは ESO の不具合ではなく、Kubernetes における env の仕様上の特徴である。
Pod vol-reader(課題5)は同じ Secret を volumeMount 経由で読み取る - このようなボリュームは
kubelet が Pod を再作成せずにディスク上で自動的に更新する。
EOF
cat /var/work/tests/artifacts/7/rotation.txt
```

## クイックチェック

```bash
check_result
```
