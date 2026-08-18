[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 102 - 参考解答(クラスターアクセス: IAM, RBAC, access entries)

すべてのコマンドは worker マシン上で SSH 経由で実行します。kubectl はすでにクラスターに
向けて設定済みです。worker ロールは `eks:*`(すべての access entry/access policy コマンド
に十分)と、`*-test-*` という名前のロールに限定された `iam:CreateRole/GetRole/DeleteRole/PutRolePolicy`
および `sts:AssumeRole` の限定的な権限を持っています - これはテスト用ロールを作成し、実際に
そのロールへ assume-role するのに十分で、他のラボの権限には手を出しません。

## 第二のプリンシパルの選択

クラスターはすでに `eks_v2_control_plane` モジュールによって `authenticationMode = API`
モード(v21 `terraform-aws-modules/eks/aws`、`enable_cluster_creator_admin_permissions = true`)
で作成されています。worker ロールはすでに `AmazonEKSClusterAdminPolicy` を持つ独自の
access entry(`terraform/modules/eks_v2_work_pc/iam.tf`)を持っています - これはクラスター
で API access entries が有効化され機能していることを裏付けます。

このラボの課題には、まだクラスターへのアクセス権を持たない**第二**の IAM プリンシパルが
必要です。Karpenter のノードロールはこの用途には使えません: `terraform-aws-modules/eks/aws//modules/karpenter`
サブモジュールはデフォルトで(`create_access_entry = true`)このロール用に `EC2_LINUX` タイプ
の access entry を自動作成しますが、1 つの IAM プリンシパルは同時に 2 つの access entry に
属することができません。そのためこのラボでは、worker から AWS CLI を使って別のテスト用ロール
を作成し、信頼関係は worker ロール自身に限定します(`sts:AssumeRole` は worker ロールの ARN
に対してのみ許可され、他の誰にも許可されません)。

## 課題1. インベントリ: authenticationMode

```bash
mkdir -p /var/work/tests/artifacts/1
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
aws eks describe-cluster --name "$CLUSTER" --query 'cluster.accessConfig' \
  > /var/work/tests/artifacts/1/accessconfig.json
cat /var/work/tests/artifacts/1/accessconfig.json
```

期待される出力は次のようになります:

```json
{
    "authenticationMode": "API",
    "bootstrapClusterCreatorAdminPermissions": true
}
```

`authenticationMode` が `API` になっている - クラスターに `aws-auth` ConfigMap は存在せず、
すべてのプリンシパルのマッピングは access entries を経由します。

## 課題2. 第二のプリンシパルとしてのテスト用 IAM ロール

worker ロールの ARN と account id を取得します(このロールにテスト用ロールへの assume を
許可します):

```bash
WORKER_ARN=$(aws sts get-caller-identity --query Arn --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "$WORKER_ARN"
```

EC2 プロファイルのインスタンス上での `get-caller-identity` は、ロール自体の ARN ではなく
**セッション**の ARN(`assumed-role/.../i-...`)を表示します。trust policy と access entry
にはロールの ARN が必要なので、セッションから組み立てます:

```bash
ROLE_NAME=$(echo "$WORKER_ARN" | sed -E 's#.*assumed-role/([^/]+)/.*#\1#')
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
echo "$ROLE_ARN"
```

テスト用ロールを作成します。名前には必ず `-test-` を含める必要があります。そうしないと
worker はそのロールを作成することも assume することもできません(IAM ポリシーがこの部分
文字列に限定されているため):

```bash
TEST_ROLE_NAME="eks-task102-test-viewer"

cat > /tmp/trust.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": { "AWS": "${ROLE_ARN}" }
    }
  ]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)

mkdir -p /var/work/tests/artifacts/2
echo "$TEST_ROLE_ARN" > /var/work/tests/artifacts/2/test_role_arn.txt
cat /var/work/tests/artifacts/2/test_role_arn.txt
```

このロールには assume 以外の IAM 権限は一切不要です - その実際の権限はすべて IAM ではなく、
クラスター側の access entry と access policy/RBAC によって与えられます。

## 課題3. テスト用ロールの access entry、viewers グループ

```bash
CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers \
  --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

`username` は指定しません - ドキュメントが推奨するとおり、EKS が自動的に設定します。これで
プリンシパルはクラスターに認識され、Kubernetes の `viewers` グループに属しますが、まだ何の
権限もありません: entry 自体は権限を与えるものではなく、RBAC のためのサブジェクトを提供する
だけです。

## 課題4. viewers グループ用の ClusterRole と ClusterRoleBinding

access policy を使わない、access entry の上に乗せる従来型の RBAC です:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: viewers-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: viewers-pod-reader
subjects:
- kind: Group
  name: viewers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: viewers-pod-reader
  apiGroup: rbac.authorization.k8s.io
EOF

kubectl get clusterrole viewers-pod-reader -o yaml
kubectl get clusterrolebinding viewers-pod-reader -o yaml
```

`viewers` グループは、これですべての namespace の pod を読み取れるようになりましたが、
それ以外の権限はありません。

## 課題5. assume-role による権限の手動確認

これは学生が手動で行うステップです - 自動テストは結果のアーティファクトのみを検証し、
assume-role 自体は検証しません(一時的な認証情報は `tests.bats` の中では不要です)。

テスト用ロールの一時的な認証情報と、別名(alias)付きの個別 kubeconfig を取得します:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name test-viewer-session)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-viewer --kubeconfig /tmp/test-viewer.kubeconfig

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
```

期待される結果: `get pods -A` は成功します(`viewers` グループへの RBAC バインディングに
より読み取りのみ許可されているため)。一方 `create namespace test` は `Forbidden` で失敗
します - `viewers` の RBAC には `namespaces` に対する権限が含まれていません。worker 自身
の権限に戻します:

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

手動確認の結果をアーティファクトとして保存します:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/rbac_check.txt <<'EOF'
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> 成功: viewers-pod-reader の RBAC バインディングが pods への get/list を許可している。

kubectl --kubeconfig /tmp/test-viewer.kubeconfig create namespace test
  -> Forbidden: viewers グループには namespace 作成の権限がなく、
     access entry はサブジェクトを与えたが、RBAC はこの操作を許可していない。
EOF
cat /var/work/tests/artifacts/5/rbac_check.txt
```

## 課題6. access entry の上に乗せる AmazonEKSViewPolicy access policy

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN"
```

これでテスト用ロールは 2 つの独立した権限のソースを持つことになります: RBAC の `viewers`
グループ(pods への get/list)と、`AmazonEKSViewPolicy` access policy(secrets を除く
クラスターのほとんどのリソースの読み取り)です。注意点として、`kubectl --kubeconfig
/tmp/test-viewer.kubeconfig auth can-i --list` は access policy による権限を表示しません
- それは RBAC オブジェクトとして表現されておらず、それを確認する唯一の方法は
`list-associated-access-policies` です。

## 課題7. 診断: Unauthorized と Forbidden の違い

実際のコマンドで違いを示します。access entry を**持たない**別のロールを作成します - これは
クラスターにとって未知のロールになります:

```bash
NOBODY_ROLE_NAME="eks-task102-test-nobody"
aws iam create-role --role-name "$NOBODY_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json
NOBODY_ARN=$(aws iam get-role --role-name "$NOBODY_ROLE_NAME" --query 'Role.Arn' --output text)

CREDS2=$(aws sts assume-role --role-arn "$NOBODY_ARN" --role-session-name nobody-session)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS2" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

aws eks update-kubeconfig --name "$CLUSTER" --region eu-central-1 \
  --alias test-nobody --kubeconfig /tmp/test-nobody.kubeconfig

kubectl --kubeconfig /tmp/test-nobody.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
aws iam delete-role --role-name "$NOBODY_ROLE_NAME"
```

これを、課題5のテスト用ロール(`test-viewer.kubeconfig`)で namespace を作成しようとした
場合と比較します - そちらではクラスターはプリンシパルを認識していますが、RBAC がその操作を
許可しません、つまり `Forbidden` になります。違いは一点に尽きます: `Unauthorized` は
クラスターがその ARN に対する access entry を全く見つけられなかったことを意味します
(`aws eks list-access-entries` にはその ARN が表示されません)。`Forbidden` は access entry
は存在するが、RBAC/access policy がその操作を許可していないことを意味します。

```bash
aws eks list-access-entries --cluster-name "$CLUSTER"
```

説明をアーティファクトとして保存します:

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt <<'EOF'
Unauthorized (401): eks-task102-test-nobody ロールはクラスターに access entry を持って
いない。そのkubeconfigでの kubectl get pods -A は "You must be logged in to the server
(Unauthorized)" と応答する - RBAC にすら到達せず、認証自体が失敗している。確認方法:
aws eks list-access-entries --cluster-name <cluster> にはこの ARN が含まれない。

Forbidden (403): eks-task102-test-viewer ロールは access entry(viewers グループ)を持ち
pods を読み取れるが、同じロールで kubectl create namespace test を実行すると Forbidden と
応答する - クラスターはプリンシパルを認識しているが、viewers グループの RBAC は namespace
の作成を許可していない。
EOF
cat /var/work/tests/artifacts/7/unauthorized_vs_forbidden.txt
```

## 課題8. access entry の削除と復元

access entry を削除してアクセスが失われたことを確認し、その後 entry を再作成します
(クラスターは採点のために動作可能な状態を維持します):

```bash
aws eks delete-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" --role-session-name test-viewer-2)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["AccessKeyId"])')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SecretAccessKey"])')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | python3 -c \
  'import json,sys;print(json.load(sys.stdin)["Credentials"]["SessionToken"])')

kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
# error: You must be logged in to the server (Unauthorized)

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws eks create-access-entry --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --kubernetes-groups viewers --type STANDARD

aws eks describe-access-entry --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

`delete-access-entry` は entry と一緒にそのすべての access policy 関連付けも削除します -
課題6のポリシー(`AmazonEKSViewPolicy`)は entry の削除後に自動的には復元されません。
スタンドを課題6で到達した状態に戻すため、明示的に復元します:

```bash
aws eks associate-access-policy --cluster-name "$CLUSTER" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster

aws eks list-associated-access-policies --cluster-name "$CLUSTER" --principal-arn "$TEST_ROLE_ARN"
```

削除/復元サイクルの結果をアーティファクトとして保存します:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/delete_recreate.txt <<'EOF'
aws eks delete-access-entry --cluster-name <cluster> --principal-arn <test_role_arn>
kubectl --kubeconfig /tmp/test-viewer.kubeconfig get pods -A
  -> error: You must be logged in to the server (Unauthorized): access entry の削除に
     よってプリンシパルが即座にクラスターにとって未知の存在になった。

aws eks create-access-entry --cluster-name <cluster> --principal-arn <test_role_arn> \
  --kubernetes-groups viewers --type STANDARD
  -> アクセスが復元された。viewers グループへの RBAC バインディングは変更されておらず、
     再び機能する。
EOF
cat /var/work/tests/artifacts/8/delete_recreate.txt
```

## クイックチェック

```bash
check_result
```
