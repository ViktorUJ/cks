[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 121 - 参考解答 (アクセスのトラブルシューティング: access entries, IRSA, kubeconfig)

すべてのコマンドはSSH経由でワーカーマシン上で実行します。kubectlはクラスター用に既に設定されており、terraformは`eks_irsa_break_demo`コンポーネントのS3バケットとIRSAロールを既に作成しています - それらの名前とARNはヒントファイル`/home/ubuntu/lab121_hints.txt`にあります。

```bash
cat ~/lab121_hints.txt
```

解答の残りの部分ではそのファイルの変数を使います:

```bash
export BUCKET_NAME=$(grep '^bucket_name' ~/lab121_hints.txt | awk '{print $3}')
export IRSA_ROLE_ARN=$(grep '^irsa_role_arn' ~/lab121_hints.txt | awk '{print $3}')
export CLUSTER_NAME=$(grep '^cluster_name' ~/lab121_hints.txt | awk '{print $3}')
```

このラボは第47章にある2つの独立したアクセス軸をカバーしています: 人間/CIがクラスターに入れないケース (タスク1-4) と、podがAWS上で`AccessDenied`になるケース (タスク5-8) です。

## タスク1. Namespace `eks-121`

```bash
kubectl create namespace eks-121
```

## タスク2. Unauthorizedの症状: access entryを持たないロール

access entryが全くないテスト用IAMロールを作成します。ワーカーのロールは名前に`-test-`を含むロールの管理しか許可していないため (`eks_v2_work_pc`モジュールの`iam.tf`を参照)、名前にはそのサブ文字列を含める必要があります:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
TEST_ROLE_NAME="eks-task121-test-noaccess"

cat > /tmp/trust-worker.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "AWS": "$(aws sts get-caller-identity --query Arn --output text)" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

aws iam create-role --role-name "$TEST_ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-worker.json

export TEST_ROLE_ARN=$(aws iam get-role --role-name "$TEST_ROLE_NAME" \
  --query 'Role.Arn' --output text)
```

ワーカーのロールは、名前に`-test-`を含むARNに対して特別に`sts:AssumeRole`を持っているため、このロールを直接assumeできます:

ここでは順序が重要です。**ワーカーの認証情報を使って**、`assume-role`の**前に**、別のkubeconfigを構築します: `aws eks update-kubeconfig`は`eks:DescribeCluster`を呼び出しますが、テストロールにはIAMポリシーが全くないため、そのロールの下ではこのコマンドが`AccessDeniedException`で失敗し、ファイルが作成されないからです。ちなみにこれが、このチェーンの3番目の失敗タイプです: IAMからの`AccessDenied` (AWS APIへの権限がない) は、`Unauthorized` (アイデンティティがクラスターにマッピングされていない) とも`Forbidden` (RBAC) とも異なります。`kubectl`自体はその後`aws eks get-token`経由でトークンを取得し、そのトークンは環境変数に入っているどのアイデンティティの認証情報からでも取得されます:

```bash
aws eks update-kubeconfig --name "$CLUSTER_NAME" --kubeconfig /tmp/kubeconfig-test

CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-noaccess --duration-seconds 900)

export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')
```

このアイデンティティのクラスターへのアクセスをチェックします - access entryが全くないためマッピングされておらず、`Unauthorized`が期待されます (第47章、47.3節):

```bash
mkdir -p /var/work/tests/artifacts/2
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/2/unauthorized.txt 2>&1
cat /var/work/tests/artifacts/2/unauthorized.txt
```

ファイルには`Unauthorized`という単語を含む行があるはずです - APIサーバーはこのIAMアイデンティティをどのaccess entryやaws-authレコードにも一致させられませんでした。

ワーカーの認証情報を復元します (セッションの変数はもう不要です):

```bash
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## タスク3. Unauthorizedの修正: access entry + AmazonEKSViewPolicy

テストロール用のaccess entryを作成し、クラスタースコープで`AmazonEKSViewPolicy`アクセスポリシーを付与します (第47章、47.4節):

```bash
aws eks create-access-entry --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" --type STANDARD

aws eks associate-access-policy --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$TEST_ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy \
  --access-scope type=cluster
```

`assume-role`を繰り返します (最初のセッションは既に期限切れまたは終了しています) - そして同じ一時的なkubeconfigで同じリクエストを送ります。今度は`Unauthorized`ではなく、podリストが返るはずです:

```bash
CREDS=$(aws sts assume-role --role-arn "$TEST_ROLE_ARN" \
  --role-session-name lab121-access --duration-seconds 900)
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.Credentials.SessionToken')

mkdir -p /var/work/tests/artifacts/3
kubectl --kubeconfig /tmp/kubeconfig-test get pods -A \
  > /var/work/tests/artifacts/3/authorized.txt 2>&1
cat /var/work/tests/artifacts/3/authorized.txt
```

ファイルには今度は`NAMESPACE ... POD ...`のような行があります - access entryによって`Unauthorized`エラーが解消されました。

## タスク4. Forbiddenの症状: Viewアクセスでは書き込みができない

このロールには`AmazonEKSViewPolicy` (読み取り) しかありません。同じ一時的なkubeconfigでnamespaceの作成を試みます - RBACは`Forbidden`で拒否するはずです (第47章、47.3節):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl --kubeconfig /tmp/kubeconfig-test create namespace test-forbidden \
  > /var/work/tests/artifacts/4/forbidden.txt 2>&1
cat /var/work/tests/artifacts/4/forbidden.txt
```

同じファイルに、タスク2 (`Unauthorized`) とタスク4 (`Forbidden`) の違いの説明を追記します:

```bash
cat >> /var/work/tests/artifacts/4/forbidden.txt <<'EOF'

相違点: タスク2ではroleはクラスターに全くマッピングされていませんでした - API serverは
identityを証明できず、これがUnauthorizedです (認証の失敗、authn層)。タスク4ではidentityは
既に証明され、access entryを通じてマッピングされていますが、RBAC (AmazonEKSViewPolicyは
読み取りのみを付与) はnamespaceの作成を許可しません - これがForbiddenです (認可の失敗、
authz層)。修正方法は異なります: Unauthorizedはマッピング (access entry / aws-auth) で修正し、
ForbiddenはRBAC (Role、ClusterRole、policy binding) で修正します。
EOF
cat /var/work/tests/artifacts/4/forbidden.txt

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
```

## タスク5. 正しいIRSAアノテーションを持つServiceAccount

`eks_irsa_break_demo`ロールはterraformによって既に作成されており、そのtrust policyは`system:serviceaccount:eks-121:demo-reader`を正確に信頼しています (第16章、第47章47.6節):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader
  namespace: eks-121
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: irsa-app
  namespace: eks-121
spec:
  serviceAccountName: demo-reader
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/irsa-app -n eks-121 --timeout=120s
```

アイデンティティを確認し、S3からオブジェクトを読み取ります:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "--- caller identity ---"
  kubectl exec irsa-app -n eks-121 -- aws sts get-caller-identity
  echo "--- s3 object ---"
  kubectl exec irsa-app -n eks-121 -- aws s3 cp "s3://${BUCKET_NAME}/hello.txt" -
} > /var/work/tests/artifacts/5/irsa_ok.txt
cat /var/work/tests/artifacts/5/irsa_ok.txt
```

出力の`Arn`は`assumed-role/<prefix>-irsa-role/...`のような形になっているはずで、2番目のブロックは`hello from s3`という行 (terraformが配置したオブジェクト) になっているはずです。

## タスク6. AccessDeniedの症状: 別のnamespaceでの壊れたアノテーション

同じロールへの同じアノテーションを持つ2つ目のSAを、namespace `default`に作成します。このロールのtrust policyは`sub = system:serviceaccount:eks-121:demo-reader`を期待していますが、このSAの`sub`は`system:serviceaccount:default:demo-reader-broken`になります - 条件は一致しません (第47章、47.6節):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-reader-broken
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: ${IRSA_ROLE_ARN}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: broken-app
  namespace: default
spec:
  serviceAccountName: demo-reader-broken
  containers:
  - name: aws-cli
    image: amazon/aws-cli:2.15.0
    command: ["sleep", "3600"]
EOF

kubectl wait --for=condition=Ready pod/broken-app -n default --timeout=120s
```

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec broken-app -n default -- aws sts get-caller-identity \
  > /var/work/tests/artifacts/6/broken.txt 2>&1
cat /var/work/tests/artifacts/6/broken.txt
```

このコマンドはトークン交換エラーで失敗するはずです: `AccessDenied`または`WebIdentityErr` (正確なメッセージはSDK/CLIのバージョンによって異なりますが、要点は同じです - トークン内の`sub`がtrust policyの条件と一致しなかったため、STSは`sts:AssumeRoleWithWebIdentity`を拒否しました)。

## タスク7. 診断: アノテーションの比較と`sub`の根本原因

両方のnamespaceにあるSAアノテーションを比較し、原因を説明します:

```bash
mkdir -p /var/work/tests/artifacts/7
{
  echo "--- eks-121/demo-reader ---"
  kubectl get sa demo-reader -n eks-121 \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo "--- default/demo-reader-broken ---"
  kubectl get sa demo-reader-broken -n default \
    -o jsonpath='{.metadata.annotations.eks\.amazonaws\.com/role-arn}'
  echo
  echo
  cat <<'TXT'
両方のアノテーションは同じIRSA roleを指していますが、roleのtrust policyはSTS token上の
sub条件をチェックします: system:serviceaccount:<namespace>:<serviceaccount>。demo-readerの
場合それはsystem:serviceaccount:eks-121:demo-readerで、roleの条件と一致するため、交換が
許可されます。demo-reader-brokenの場合、tokenはsub=system:serviceaccount:default:demo-reader-
brokenを持ちます - 異なるnamespaceと異なるSA名なので、StringEquals条件が一致せず、
アノテーション内のrole ARNが同じであるという事実にかかわらず、sts:AssumeRoleWithWebIdentityは
拒否されます。
TXT
} > /var/work/tests/artifacts/7/diagnostics.txt
cat /var/work/tests/artifacts/7/diagnostics.txt
```

## タスク8. まとめ: 2つのアクセス軸

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<'EOF'
人間の軸 (タスク2-4) はチェーンkubectl - IAM - EKS authenticator - RBACの中にあります:
UnauthorizedはIAM identityが全く証明できなかったか、クラスターにマッピングできなかったことを
意味し (access entryまたはaws-authで修正)、一方Forbiddenはidentityは既に判明しているが、
RBACがその特定のアクションを許可しなかったことを意味します (Role/ClusterRoleBindingで修正)。
podの軸 (タスク5-7) はチェーンpod - ServiceAccount - STS - IAM roleの中にあります:
AccessDeniedまたはWebIdentityErrはroleのtrust policyがServiceAccount tokenのsubと一致
しなかったことを意味します (trust policyまたはSAアノテーション内のsub条件を編集して修正)。
重要な相違点: 最初の軸では修正はクラスター内のRBACであり、2番目の軸では修正はAWS内の
IAM roleのtrust policyであり、この2つを混同してはいけません。
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## クイックチェック

```bash
check_result
```
