[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 120 - 参考解答(ネットワーク障害、unhealthy な load balancer targets)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl はすでにクラスタ用
に設定されています。Terraform はすでに「壊れた」security group(コンポーネント
`eks_network_break_demo`)と、AWS Load Balancer Controller 用の IRSA ロール
(`eks_lbc_irsa`)を作成済みです - 名前と id は `~/lab120_hints.txt` にあります。

```bash
cat ~/lab120_hints.txt
export SG_ID=$(grep '^broken_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export CLUSTER=$(grep '^cluster_name' ~/lab120_hints.txt | awk '{print $3}')
```

## タスク 1。namespace とラボのワークロード

```bash
kubectl create namespace eks-120

kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-120
kubectl rollout status deployment/api -n eks-120

kubectl expose deployment api -n eks-120 --port=80 --target-port=8080 --name=api

kubectl create deployment client --image=busybox:1.36 -n eks-120 -- sleep 3600
kubectl rollout status deployment/client -n eks-120
```

## タスク 2。基本的な接続性と SG の診断

```bash
CLIENT_POD=$(kubectl get pod -n eks-120 -l app=client -o jsonpath='{.items[0].metadata.name}')

mkdir -p /var/work/tests/artifacts/2
kubectl exec -n eks-120 "$CLIENT_POD" -- \
  wget -qO- --timeout=5 http://api.eks-120.svc.cluster.local \
  > /var/work/tests/artifacts/2/connectivity.txt
cat /var/work/tests/artifacts/2/connectivity.txt
```

ここでは接続性は正常に動作します:node SG はクラスタの pod 間のトラフィックを許可して
おり、SG はステートフルであるため、このリクエストへの応答はそのまま通過します(第
46.3 章)。`api` の pod の ENI にどの SG が実際にアタッチされているかを見てみましょ
う:

```bash
API_IP=$(kubectl get pod -n eks-120 -l app=api -o jsonpath='{.items[0].status.podIP}')

ENI を見つけるためにどのフィルタを使うかが重要です。VPC CNI では、pod の IP はノード
の ENI の **secondary** アドレスであるため、フィルタ `private-ip-address`(インターフ
ェースの primary アドレスを見る)は `null` を返します。インターフェースのすべてのア
ドレスを検索する `addresses.private-ip-address` が必要です:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=addresses.private-ip-address,Values=${API_IP}" \
  --query 'NetworkInterfaces[0].Groups' \
  > /var/work/tests/artifacts/2/api_sg.txt
cat /var/work/tests/artifacts/2/api_sg.txt
```

## タスク 3。AWS Load Balancer Controller のインストール

```bash
LBC_ROLE_ARN=$(aws iam get-role --role-name "${CLUSTER}-lbc-irsa" \
  --query 'Role.Arn' --output text)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${LBC_ROLE_ARN}
EOF

helm repo add eks https://aws.github.io/eks-charts
helm repo update

この環境の重要な点:`kube-system` namespace は Fargate profile 配下にあるため、コント
ローラの pod は Fargate 上で動作し、Fargate には **IMDS がありません**。IMDS がなけれ
ば、コントローラはリージョンと VPC を自分で判定できず、`failed to get VPC ID: ...
ec2imds ... context deadline exceeded` で失敗します。そのため `region` と `vpcId` を
明示的に設定します:

```bash
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

## タスク 4。症状:unhealthy な targets を持つ NLB

「壊れた」SG を balancer 自身の security group として設定します。SG がアノテーション
経由で明示的に指定された途端、LBC は node SG への不足している受信ルールの追加を自動で
は行わなくなります - これがまさにこの障害です(第 46.6 章):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: api-lb
  namespace: eks-120
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-security-groups: ${SG_ID}
spec:
  type: LoadBalancer
  selector:
    app: api
  ports:
    - port: 80
      targetPort: 8080
EOF

kubectl get svc api-lb -n eks-120 -w
```

外部アドレスを待ち、target group を見つけ、targets の健全性を確認します:

```bash
HOSTNAME=$(kubectl get svc api-lb -n eks-120 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
  --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table > /var/work/tests/artifacts/4/unhealthy.txt
cat /var/work/tests/artifacts/4/unhealthy.txt
```

すべての targets が `unhealthy` です - balancer の SG が health check を node SG に通
過させないため、`api` の pod にも到達しません。

## タスク 5。診断:どの SG が health check を遮断しているか

```bash
aws ec2 describe-security-groups --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions'
```

空のリストがそれを裏付けています:balancer の SG には受信ルールが一つもありません。

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnosis.txt <<EOF
balancer の security group (${SG_ID}) は aws-load-balancer-security-groups
アノテーション経由で api-lb に割り当てられており、受信ルールを含んでいません。
NLB からの health check は、balancer の security group からノードの
security group (${NODE_SG}) へ、アプリケーションのポート 8080 宛ての新しい
TCP 接続として到達します。ノードの security group はこのポートで balancer
の security group からの受信トラフィックを許可していないため、health check
は失敗し、targets は unhealthy のままになります(第 46.6 章)。
EOF
cat /var/work/tests/artifacts/5/diagnosis.txt
```

## タスク 6。修復:authorize-security-group-ingress、targets が healthy になる

2 つのルール:balancer の SG から node SG への health check とアプリケーショントラフ
ィックを許可するルールと、クライアント向けに port 80 で NLB のリスナーを開くルールで
す:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$NODE_SG" \
  --protocol tcp --port 8080 \
  --source-group "$SG_ID"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 80 \
  --cidr 0.0.0.0/0
```

targets が `healthy` になるまで待ち(通常 1-2 分)、curl で検証します:

```bash
sleep 90

mkdir -p /var/work/tests/artifacts/6
{
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN" \
    --query 'TargetHealthDescriptions[].[Target.Id,TargetHealth.State]' --output table
  echo
  curl -s --max-time 5 "http://${HOSTNAME}"
} > /var/work/tests/artifacts/6/healthy.txt
cat /var/work/tests/artifacts/6/healthy.txt
```

## タスク 7。DNS は動作する:対比としてのチェック

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl run dnstest --image=busybox:1.36 --rm -i --restart=Never -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup example.com' \
  > /var/work/tests/artifacts/7/dns.txt
cat /var/work/tests/artifacts/7/dns.txt
```

内部名はその完全な FQDN で問い合わせます。busybox の `nslookup` を通した短い
`kubernetes.default` は `NXDOMAIN` を返します:このリゾルバは通常のクライアントのよう
に `/etc/resolv.conf` の search domain を追加しないため、その応答は実際には存在しない
DNS の障害と誤解しやすいものです。

両方の名前とも正常に解決されます(`kubernetes.default.svc.cluster.local` は
`kubernetes` service のアドレスに、`example.com` は外部アドレスに)- このラボでは DNS
は問題の原因ではありません(第 46.5、46.7 章)、タスク 4-6 の security group とは異な
ります。

## タスク 8。最終チェックリスト:症状 - 推定原因 - 何を確認するか

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<EOF
症状:NLB の target group 内の targets が unhealthy であり、api-lb service は
503 を返す。
推定原因:balancer の security group が、health check のポートでノード SG
への受信トラフィックを許可していない(第 46.6 章)。
何を確認するか:aws elbv2 describe-target-health --target-group-arn <arn> は
TargetHealth.Reason=Target.FailedHealthChecks を示し、aws ec2
describe-security-groups は balancer の SG に受信ルールがないことを確認する。
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## クイックチェック

```bash
check_result
```
