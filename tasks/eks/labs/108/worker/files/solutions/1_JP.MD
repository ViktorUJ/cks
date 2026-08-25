[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 108 - 参考解答(AWS Load Balancer Controller:Service 用の NLB)

すべてのコマンドはワーカーマシン上で SSH 経由で実行します。kubectl は既にクラスタ向けに
設定されています。Terraform はコントローラ用の IAM ロールを既に作成しています
(コンポーネント `eks_lbc_irsa`、モジュール `eks_v2_lbc_irsa`) - 残っているのはその ARN
を取得し、コントローラ自体をインストールすることだけです。

## タスク 1. Namespace `eks-108`

```bash
kubectl create namespace eks-108
```

## タスク 2. ServiceAccount と AWS Load Balancer Controller のインストール

terraform が作成したロールの ARN を探します(ロール名 `<cluster-name>-lbc-irsa`):

```bash
ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text)
echo "$ROLE_ARN"
```

`kube-system` にそのロールを指すアノテーションを付けて ServiceAccount を作成します。
LBC は Helm で `serviceAccount.create=false` を指定してインストールするため、
ServiceAccount は事前に存在している必要があります:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ROLE_ARN}
EOF
```

公式 chart からコントローラ自体をインストールします:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's/.*\///')
VPC_ID=$(aws eks describe-cluster --name "${CLUSTER_NAME}" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "$VPC_ID"

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=eu-central-1 \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

コントローラは Fargate 上で動作します(namespace `kube-system` は Fargate profile の
下にあります)。Fargate には EC2 instance metadata service(IMDS)が物理的に存在しない
ため、明示的な `vpcId`/`region` がなければ、コントローラは IMDS を通じて VPC ID を
取得しようとして `failed to fetch VPC ID from instance metadata: ... context deadline
exceeded` のようなエラーで `CrashLoopBackOff` に陥ります。マネージド EC2 ノードでは
これらのフラグは不要です(そこでは IMDS が利用可能です)が、Fargate では常に明示的に
渡す必要があります。

コントローラが起動し、ロールを認識していることを確認します:

```bash
kubectl get deploy aws-load-balancer-controller -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep role-arn
```

## タスク 3. Deployment `web`(viktoruj/ping_pong、2 レプリカ)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-108
kubectl rollout status deployment/web -n eks-108
```

## タスク 4. LoadBalancer タイプの Service `web`:CLB ではなく NLB

デフォルトでは、in-tree cloud provider は LoadBalancer タイプの Service に対して
古い Classic Load Balancer を作成します。アノテーション
`aws-load-balancer-type: external` は、リコンサイルを AWS Load Balancer Controller
に渡し、現代的な Network Load Balancer を作成させます:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: eks-108
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 8080
EOF
```

外部アドレスを待ちます:

```bash
kubectl get svc web -n eks-108 -w
```

AWS CLI で、CLB ではなく NLB(タイプ `network`)が作成され、scheme が
`internet-facing` であることを確認します:

```bash
HOSTNAME=$(kubectl get svc web -n eks-108 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/4/nlb.txt
cat /var/work/tests/artifacts/4/nlb.txt
```

出力では `Type` が `network`(NLB)、`Scheme` が `internet-facing` であるはずです。
`aws-load-balancer-type` アノテーションがなければ、in-tree provider は
`Type: classic` を作成していたでしょう - これはまさに第 26 章の「LoadBalancer を
要求したのに CLB を得た」という症状です。

## タスク 5. ターゲットの確認:ノードの instance ID ではなく Pod の IP

`target-type: ip` は、VPC CNI が発行した Pod のアドレスを target group に登録し、
`InstanceId` によるノードは登録しません。これを `describe-target-groups` と
`describe-target-health` で確認します:

```bash
TG_ARN=$(aws elbv2 describe-target-groups --load-balancer-arn "$LB_ARN" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

mkdir -p /var/work/tests/artifacts/5
{
  aws elbv2 describe-target-groups --target-group-arns "$TG_ARN"
  aws elbv2 describe-target-health --target-group-arn "$TG_ARN"
} > /var/work/tests/artifacts/5/targets.txt

cat /var/work/tests/artifacts/5/targets.txt
```

ファイル内で `TargetType` は `ip` であるべきで、各ターゲットの `Target.Id` は
`10.10.0.0/16`(このラボの VPC サブネット)からのアドレスであり、`i-...`
(instance ID)ではないはずです。これはまさに `target-type: ip` の NLB ターゲット
グループの姿です:コントローラは NodePort を経由せず Pod の IP を直接登録するため、
kube-proxy を経由する余分なホップがなくなります。

## タスク 6. 診断:成功したリコンサイルと AccessDenied

コントローラのログを見て、正常な Service のリコンサイルがどのように見えるかを確認
します - そこには作成されたロードバランサーの ARN が現れるはずです:

```bash
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
  | grep -i 'successfully reconciled\|loadBalancerARN\|arn:aws:elasticloadbalancing' \
  | tail -n 10
```

ServiceAccount にロールが紐付いていなかった場合(あるいはロールに必要な権限がなかった
場合)、コントローラは ELBv2 API を呼び出すことができず、ログには
`AccessDenied: User: ... is not authorized to perform:
elasticloadbalancing:CreateLoadBalancer` のようなメッセージが表示され、Service は
外部アドレスを持たないまま `<pending>` に留まります - リコンサイルが最初の API 呼び
出しの時点で、NLB が作成される前に失敗するためです。

両方の観察結果を 1 つのアーティファクトに保存します:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== 成功したリコンサイル(実際のコントローラログ) ==="
  kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
    | grep -i 'successfully reconciled\|arn:aws:elasticloadbalancing'
  echo
  echo "=== IAM 権限がない場合に想定される症状(実際のロールでは再現されていない) ==="
  echo "AccessDenied: User: arn:aws:sts::<account>:assumed-role/<cluster>-lbc-irsa/... " \
       "is not authorized to perform: elasticloadbalancing:CreateLoadBalancer " \
       "on resource: arn:aws:elasticloadbalancing:<region>:<account>:loadbalancer/*"
  echo "このエラーが出ると web Service は <pending> のままになります:" \
       "EXTERNAL-IP は決して現れません。コントローラが ELBv2 API 経由で NLB を" \
       "作成できなかったためです。"
} > /var/work/tests/artifacts/6/reconcile.txt

cat /var/work/tests/artifacts/6/reconcile.txt
```

## クイックチェック

```bash
check_result
```
