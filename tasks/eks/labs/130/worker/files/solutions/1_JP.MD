[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ130 - 参考解決策(ECRとサプライチェーン)

すべてのコマンドはSSH経由でワーカーマシン(worker)上で実行します。AWS CLIはインスタンス
ロールを通じて対象アカウントに設定済みです(余分な`aws configure`は不要)、kubectlはラボの
クラスターに設定済みです。`docker`の代わりに`podman`を使用します(ワーカーにインストール
済みです)。

アカウントIDとプライベートレジストリのアドレスを一度だけ定義します:

```bash
export AWS_REGION=eu-central-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_HOST="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
echo "$ECR_HOST"
```

## タスク1. IMMUTABLEタグとscanOnPush付きリポジトリ

```bash
aws ecr create-repository \
  --repository-name eks-lab130/app \
  --image-tag-mutability IMMUTABLE \
  --image-scanning-configuration scanOnPush=true \
  --region "$AWS_REGION"

aws ecr describe-repositories --repository-names eks-lab130/app --region "$AWS_REGION"
```

出力に`imageTagMutability: IMMUTABLE`と`imageScanningConfiguration.scanOnPush: true`が
あることを確認してください。

## タスク2. タグv1でイメージをpush

12時間有効なトークンでレジストリにログインし、パブリックイメージを再タグ付けします:

```bash
aws ecr get-login-password --region "$AWS_REGION" \
  | podman login --username AWS --password-stdin "$ECR_HOST"

podman pull docker.io/library/alpine:3.19
podman tag docker.io/library/alpine:3.19 "$ECR_HOST/eks-lab130/app:v1"
podman push "$ECR_HOST/eks-lab130/app:v1"

aws ecr describe-images --repository-name eks-lab130/app --region "$AWS_REGION"
```

`describe-images`の出力にはタグ`v1`のイメージが1つあるはずです。

実務上の重要な点が2つあります。1つ目: `alpine`はここで「軽いから」選んだわけではなく、
ECRの基本スキャンがそのパッケージデータベースを解析できるためです - タスク4で本物の
findingsが得られます(実機確認済み: `alpine:3.19`でHIGH 1件、MEDIUM 1件、LOW 2件)。2つ目:
タスク2-6は同じSSHセッション内で行ってください。`podman login`はトークンを
`$XDG_RUNTIME_DIR/containers/auth.json`に書き込みますが、このディレクトリはユーザー
セッションと一緒に削除されるため、再接続後はECRの12時間トークンがまだ有効でも、pushは
`unauthorized: authentication required`を返します。

## タスク3. 症状: タグv1の再pushが拒否される

別のイメージを取得し、同じ`v1`でタグ付けして上書きを試みます:

```bash
podman pull docker.io/library/busybox:1.36
podman tag docker.io/library/busybox:1.36 "$ECR_HOST/eks-lab130/app:v1"

mkdir -p /var/work/tests/artifacts/3
podman push "$ECR_HOST/eks-lab130/app:v1" 2>&1 \
  | tee /var/work/tests/artifacts/3/denied.txt
```

pushはレジストリの拒否で終わります(実機確認済み):

```
tag invalid: The image tag 'v1' already exists in the 'eks-lab130/app' repository
and cannot be overwritten because the tag is immutable.
```

これがIMMUTABLEの動作です: タグ`v1`は最初のイメージによってすでに使用されており、
上書きできません。出力は長くなります - `podman`は複数のマニフェスト形式(OCI、
docker v2、docker v1)を順に試し、それぞれで同じ拒否を受け取ります。アーティファクト
`denied.txt`には、必要な行がどの試行にも含まれています。この時点でレイヤーは既に
アップロードされていることに注意してください: IMMUTABLEが保護しているのはまさに
「タグの紐付け」であり、blobストレージそのものではありません。

## タスク4. スキャンのfindings(プッシュ時スキャン)

スキャンはpush時(タスク2)に自動的に開始されます。retryループで完了を待ちます
(このバージョンのCLIには待機用の専用コマンドがあります):

```bash
aws ecr wait image-scan-complete \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION"

mkdir -p /var/work/tests/artifacts/4
aws ecr describe-image-scan-findings \
  --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
  --query '{status: imageScanStatus.status, bySeverity: imageScanFindings.findingSeverityCounts}' \
  > /var/work/tests/artifacts/4/scan-summary.txt

cat /var/work/tests/artifacts/4/scan-summary.txt
```

お使いのCLIバージョンで`aws ecr wait image-scan-complete`が使えない場合は、手動の
retryループに置き換えてください:

```bash
for i in $(seq 1 30); do
  status=$(aws ecr describe-image-scan-findings \
    --repository-name eks-lab130/app --image-id imageTag=v1 --region "$AWS_REGION" \
    --query 'imageScanStatus.status' --output text 2>/dev/null)
  [[ "$status" == "COMPLETE" ]] && break
  sleep 5
done
```

`findingSeverityCounts`にはseverity別のfindings数が表示されます - `alpine:3.19`では
`{"HIGH": 1, "MEDIUM": 1, "LOW": 2}`でした(実機確認済み、実際の数値はスキャン日と
脆弱性データベースに依存します)。

自分で確認しておくべき重要な適用範囲の限界があります。ECRの基本スキャンは既知の
ディストリビューションのパッケージデータベースを読み取るため、`FROM scratch`(例えば
静的にビルドされたGoバイナリ)やdistrolessでビルドされたイメージはスキャンできません:

```bash
aws ecr describe-image-scan-findings --repository-name eks-lab130/app \
  --image-id imageTag=<scratchイメージのタグ> --region "$AWS_REGION" \
  --query 'imageScanStatus' --output json
# {
#   "status": "FAILED",
#   "description": "UnsupportedImageError: The operating system and/or package manager
#                   are not supported."
# }
```

ここから実務上の結論が得られます: 「スキャナーが脆弱性を見つけなかった」ことと
「スキャナーが確認できなかった」ことは異なるものであり、サマリーレポートでは容易に
「問題なし」に混ざってしまいます。ゲートのポリシーがクリーンなスキャンを要求するなら、
findingsの数だけでなくステータス自体を確認してください。

## タスク5. digestでのデプロイ

イメージ`v1`のdigestはECRから取得できます(`podman inspect`より確実です。これは
レジストリに実際に置かれているマニフェストそのもののdigestだからです):

```bash
DIGEST=$(aws ecr describe-images --repository-name eks-lab130/app --image-ids imageTag=v1 \
  --region "$AWS_REGION" --query 'imageDetails[0].imageDigest' --output text)
echo "$DIGEST"

kubectl create namespace eks-130 --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: digest-app
  namespace: eks-130
  labels:
    app: digest-app
spec:
  nodeSelector:
    kubernetes.io/arch: amd64
  containers:
  - name: app
    image: ${ECR_HOST}/eks-lab130/app@${DIGEST}
    command: ["sh", "-c", "sleep 86400"]
EOF

kubectl wait --for=condition=Ready pod/digest-app -n eks-130 --timeout=600s
kubectl get po -n eks-130 digest-app -o wide
```

ここでの`nodeSelector`は必須で、これはよく引っかかる罠です。ワーカーマシンは
x86_64のため、`podman push`はシングルアーキテクチャのマニフェスト(`amd64`のみ)を
ECRに送信しましたが、このラボのNodePoolは`arm64`も許可しています。実機確認済み:
セレクターがないとKarpenterは`t4g.small`を起動し、イメージは問題なくダウンロード
されますが、コンテナは`exitCode 255`かつログが空のまま停止します -
理由の分からない`CrashLoopBackOff`です。同種の問題はラボ124でも取り上げています
(イメージ`polinux/stress`が`amd64`専用でした)。プロダクションでの結論: マルチ
アーキテクチャのマニフェストをビルドするか、ワークロードを明示的にアーキテクチャに
固定するかのどちらかが必要です。

Karpenterのノードロールはすでにmanaged policy `AmazonEC2ContainerRegistryReadOnly`を
持っている(`eks_v2_karpenter`モジュールで設定済み)ため、podはイメージのpullに成功し、
`imagePullSecrets`なしで`Running`に遷移します。`@sha256:`による参照は、タスク2-4で
スキャンし検証したまさにそのバイト列を固定します - タグはずれることがあっても、
digestはずれません。

## タスク6. registry.k8s.io向けpull through cache

認証なしのルールです - アップストリームはパブリックです:

```bash
aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix k8s-cache \
  --upstream-registry-url registry.k8s.io \
  --region "$AWS_REGION"
```

アカウント内で最初のルールを作成すると、ECRはservice-linked role
`AWSServiceRoleForECRPullThroughCache`を作成するため、呼び出し側には
`iam:CreateServiceLinkedRole`権限が必要です(ワーカーマシンのポリシーには
`iam:AWSServiceName = pullthroughcache.ecr.amazonaws.com`という条件付きで付与
されています)。この権限がない場合、ECRはIAMユーザーに直接関する応答ではなく、
パラメータエラーと誤解しやすいラッパーで応答します:
`ValidationException ... The Amazon ECR action failed due to an IAM exception: ... is not
authorized to perform: iam:CreateServiceLinkedRole`(実機で再現済み)。

キャッシュ経由の最初のpullで、あなたのECRにリポジトリ`k8s-cache/pause`が作成され、
イメージがキャッシュされます:

```bash
podman pull "${ECR_HOST}/k8s-cache/pause:3.9"

aws ecr describe-repositories --region "$AWS_REGION" \
  --query "repositories[?starts_with(repositoryName,'k8s-cache/pause')].repositoryName"
```

## タスク7. シークレット付きDocker Hub pull through cache(実際のpullなし)

このラボのテーマはシークレットそのものなので、本物のシークレットを作成しますが、
本物のDocker Hubトークンの代わりにダミー値を使います: このような認証情報で実際の
pullは成功しませんが、設定(シークレットとcache rule)はそれによって壊れることなく、
完全に検証できます。

```bash
aws secretsmanager create-secret \
  --name ecr-pullthroughcache/dockerhub-creds \
  --description "Docker Hub creds for ECR pull through cache (lab placeholder)" \
  --secret-string '{"username":"lab-placeholder-user","accessToken":"lab-placeholder-token"}' \
  --region "$AWS_REGION"

SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id ecr-pullthroughcache/dockerhub-creds --region "$AWS_REGION" \
  --query 'ARN' --output text)
echo "$SECRET_ARN"

aws ecr create-pull-through-cache-rule \
  --ecr-repository-prefix docker-hub \
  --upstream-registry-url registry-1.docker.io \
  --credential-arn "$SECRET_ARN" \
  --region "$AWS_REGION"

aws ecr describe-pull-through-cache-rules --region "$AWS_REGION"
```

シークレットには必ず`ecr-pullthroughcache/`プレフィックスを付けてください -
そうでないとECRはcache ruleでそれを受け付けません。このダミー値で`docker-hub/...`を
通じて実際に`podman pull`を行うと、当然失敗します(認証情報が本物ではないため) -
このタスクは設定(シークレットとルールが存在すること)を検証するもので、pullの成功
自体は確認しません。実際にキャッシュ経由でpullが成功する例はタスク6
(registry.k8s.io、認証なし)で扱っています。

重要: ここでは本物のDocker Hub認証情報を使わないでください。このシークレットは
あくまでラボ自体の設定検証のためのものです。

## タスク8. Lifecycle policy

ルール: タグ`v.*`のイメージを5個までしか保持せず、それ以外はタグの古さに基づいて
削除します:

```bash
cat <<'EOF' > /tmp/lifecycle.json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "keep last 5 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": { "type": "expire" }
    }
  ]
}
EOF

aws ecr put-lifecycle-policy \
  --repository-name eks-lab130/app \
  --lifecycle-policy-text file:///tmp/lifecycle.json \
  --region "$AWS_REGION"

aws ecr get-lifecycle-policy --repository-name eks-lab130/app --region "$AWS_REGION"
aws ecr start-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION" >/dev/null
sleep 5
aws ecr get-lifecycle-policy-preview \
  --repository-name eks-lab130/app --region "$AWS_REGION"
```

`get-lifecycle-policy-preview`はすぐに結果を返さないことがあります(プレビューは
非同期で計算されます) - ステータスがまだ`IN_PROGRESS`の場合は、数秒後に再度
リクエストしてください。

## クイックチェック

```bash
check_result
```
