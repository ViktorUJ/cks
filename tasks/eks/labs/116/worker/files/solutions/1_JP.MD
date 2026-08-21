[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 116 - リファレンス解答 (IMDSv2 hop limit、Pod Security Admission、プライベート endpoint)

すべてのコマンドは worker マシン上で SSH 経由で実行します。kubectl はすでにクラスタ
向けに設定済みです (kubeconfig はマシン起動時に `aws eks update-kubeconfig` で作成され
ています)。

## タスク 1. Namespace `eks-116`

```bash
kubectl create namespace eks-116
```

## タスク 2. 症状: pod から IMDS に到達できない

このラボで唯一の NodePool `hardened` は、EC2NodeClass の `metadataOptions` を通じて
すべての node に `httpPutResponseHopLimit=1` を設定します。host 上のプロセスからの
パケットは 1 hop で IMDS に届きますが、pod からのパケットはもう 1 hop 余分にかかり
(コンテナのネットワーク namespace) - このため limit に収まりません。exec で入れるよう
に、スリープするコンテナを持つ Deployment を作成します:

```bash
kubectl create deployment probe --image=curlimages/curl:latest -n eks-116 \
  -- sleep 3600
kubectl rollout status deployment/probe -n eks-116
```

pod から IMDSv2 リクエストを実行します (最初に token、次にデータ)、時間制限付きで:

```bash
POD=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].metadata.name}')
mkdir -p /var/work/tests/artifacts/2

kubectl exec -n eks-116 "$POD" -- sh -c '
  echo "=== PUT token ===";
  TOKEN=$(curl -sX PUT --max-time 5 "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600");
  if [ -z "$TOKEN" ]; then
    echo "no token received: request timed out (hop limit blocked the pod)";
  else
    echo "=== GET with token ===";
    curl -s --max-time 5 -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/ \
      || echo "GET timed out (hop limit blocked the pod)";
  fi
' 2>&1 | tee /var/work/tests/artifacts/2/imds.txt

cat /var/work/tests/artifacts/2/imds.txt
```

hop limit が `1` の場合、`curl` は与えられた `5` 秒以内に応答を受け取れず、ファイルには
timeout に関する行が残ります (`curl` は `-v` 付きで `curl: (28) ... timeout` を出力し、
token を受け取れなかった場合はスクリプト自身が `timed out` という説明を追加します)。

## タスク 3. AWS API による確認: node 上の hop limit と IMDSv2

`probe` がどの node で動いているか確認し、その `providerID` を取得して instance id を
抜き出します:

```bash
NODE=$(kubectl get po -n eks-116 -l app=probe -o jsonpath='{.items[0].spec.nodeName}')
PROVIDER_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}')
# providerID は aws:///eu-central-1a/i-0abc123def456789 の形式
INSTANCE_ID=$(echo "$PROVIDER_ID" | awk -F'/' '{print $NF}')
echo "node=$NODE instance=$INSTANCE_ID"

mkdir -p /var/work/tests/artifacts/3
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[].Instances[].MetadataOptions' --output json \
  | tee /var/work/tests/artifacts/3/metadata_options.txt
```

出力には `"HttpTokens": "required"` と `"HttpPutResponseHopLimit": 1` が含まれるはず
です - これはまさに `eks_karpenter_hardened_vng/terragrunt.hcl` の
`vng.metadataOptions` が設定した値であり、EC2NodeClass が node の launch template に
渡した値です。

## タスク 4. Pod Security Admission: privileged な pod の拒否

ラベルによって namespace 上で restricted を有効化します (PSA は EKS に組み込まれて
いますが、ラベルがない namespace はデフォルトで `privileged` として動作します - 何も
制限しません):

```bash
kubectl label namespace eks-116 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest
```

privileged な pod を試します - admission は作成を拒否するはずです:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl run priv-test -n eks-116 --image=busybox --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"priv-test","image":"busybox","securityContext":{"privileged":true}}]}}' \
  2>&1 | tee /var/work/tests/artifacts/4/psa_reject.txt

kubectl get pod priv-test -n eks-116 2>&1 | tee -a /var/work/tests/artifacts/4/psa_reject.txt
cat /var/work/tests/artifacts/4/psa_reject.txt
```

期待される出力は次のようになります:

```
Error from server (Forbidden): pods "priv-test" is forbidden: violates PodSecurity "restricted:latest": privileged (container "priv-test" must not set securityContext.privileged=true)
```

pod は作成されず (`kubectl get pod priv-test` は `NotFound` を返します)、メッセージには
`privileged` と `restricted`/`violates` という語が含まれます - これがまさに受け入れ
基準が求めているものです。

## タスク 5. 許可される道: restricted に適合する pod

`restricted` プロファイルが要求するすべてのフィールドを持つ pod を組み立てます。
`runAsNonRoot: true` は root として実行することのみを禁止します - `busybox:latest`
イメージはデフォルトで non-root ユーザーを宣言していないため、明示的な `runAsUser`
(ゼロでない任意の UID) がなければ、admission が pod を通過させた後に kubelet が
`container has runAsNonRoot and image will run as root` という別のエラーでコンテナの
起動をブロックします:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: safe-pod
  namespace: eks-116
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
EOF

kubectl get pod safe-pod -n eks-116 -o wide
```

この pod は admission を通過し `Running` になります - 同じ namespace、同じ
`restricted` プロファイルですが、要件は完全に満たされています: 明示的な `runAsUser`
を伴う `runAsNonRoot`、`allowPrivilegeEscalation: false`、
`capabilities.drop: ["ALL"]`、`seccompProfile` `RuntimeDefault`。

## タスク 6. control plane へのプライベートアクセスと VPC endpoints

クラスタの `resourcesVpcConfig` を確認します - `eks_v2_control_plane` モジュールは
すでに両方のフラグを有効にしています (`endpoint_public_access = true`、
`endpoint_private_access = true`):

```bash
CLUSTER=$(kubectl config current-context | sed 's|.*/||')
mkdir -p /var/work/tests/artifacts/6

aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig' --output json \
  | tee /var/work/tests/artifacts/6/private_endpoint.txt
```

出力には `"endpointPrivateAccess": true` が表示されます。ファイルに説明を追記します:

```bash
cat >> /var/work/tests/artifacts/6/private_endpoint.txt <<'EOF'

完全にプライベートなクラスタ (インターネットに出られない node) には VPC endpoints が
必要です: ecr.api と ecr.dkr (コンテナイメージを pull するため)、s3 gateway endpoint
(ECR イメージのレイヤーは物理的に S3 に置かれているため、ecr.api と ecr.dkr があっても
これがなければイメージはダウンロードできません)、sts (IRSA token を一時的な
credentials に交換する)、ec2 (node の登録と DNS 名)、logs (ログを CloudWatch に送る)、
そして eks (VPC から EKS API にアクセスする)。control plane のプライベートアクセス
(このクラスタではすでに有効) は endpoint のリストとは別に必須です - これがなければ、
node はプライベートサブネットから API server に登録できません。
EOF

cat /var/work/tests/artifacts/6/private_endpoint.txt
```

## クイックチェック

```bash
check_result
```
