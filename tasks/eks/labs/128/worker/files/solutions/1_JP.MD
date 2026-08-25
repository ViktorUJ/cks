[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ128 - 参考解答(AWSにおけるGateway API: ALB Gateway APIとVPC Lattice)

すべてのコマンドはワーカーマシン上でSSH経由で実行します。kubectlはすでにクラスタに
対して設定されています。Terraformは両方のコントローラー用にIAMロールをすでに作成し
ています(コンポーネント`eks_lbc_irsa`、`eks_vpclattice_irsa`) - それらのARNは
`~/lab128_hints.txt`にあります。

```bash
cat ~/lab128_hints.txt
export CLUSTER=$(kubectl config current-context | sed 's|.*/||')
export LBC_ROLE_ARN=$(grep '^lbc_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export LATTICE_ROLE_ARN=$(grep '^vpclattice_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab128_hints.txt | awk '{print $3}')
export VPC_ID=$(grep '^vpc_id' ~/lab128_hints.txt | awk '{print $3}')
export ACCOUNT_ID=$(grep '^account_id' ~/lab128_hints.txt | awk '{print $3}')
export REGION=eu-central-1
```

## タスク1. Gateway API CRDとラボのnamespace

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl create namespace eks-128
kubectl create namespace eks-128-backend
```

## タスク2. AWS Load Balancer ControllerとALBクラスのGateway(L7)

```bash
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

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

`region`と`vpcId`はここでは必須で、これは装飾ではありません。コントローラーのpod
は`kube-system`に配置されますが、このnamespaceはFargateプロファイルに覆われてお
り、そこにはIMDSがまったくありません。これらのフラグがないと、コントローラーは
`failed to get VPC ID ... ec2imds: GetMetadata ... context deadline exceeded`とと
もに`CrashLoopBackOff`に陥ります(検証済み)。まったく同じ落とし穴が、Fargate上の
`kube-system`に設置するあらゆるコントローラーを待ち構えています(第15章と第26
章)。

ALB用の`GatewayClass`と`Gateway`自体を作成します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: eks-128
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway web -n eks-128 -o wide
```

`gateway.k8s.aws/alb`は、ラボ108/109にあるものと同じAWS Load Balancer
Controllerで、入口がIngressの代わりにGateway APIのリソースで記述されているだけです:
L7ルートである`HTTPRoute`と`GRPCRoute`は、ALBのlistenerとルールに変換されます(第28
章、28.4節)。

## タスク3. ALB上のHTTPRoute: アプリケーションのルーティング

```bash
kubectl create deployment frontend --image=viktoruj/ping_pong:latest \
  --replicas=2 -n eks-128
kubectl rollout status deployment/frontend -n eks-128
kubectl expose deployment frontend -n eks-128 --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - backendRefs:
        - name: frontend
          port: 80
EOF
```

ルートが1つあるだけでは足りません: コントローラーに、どの種類のターゲットを登録すべ
きか教える必要があります。種類はデフォルトで`instance`と推論され、`instance`には
`NodePort`または`LoadBalancer`タイプのServiceが必要です。`ClusterIP`のままだと、
ロードバランサーは設定が完了しない状態になります: `Gateway`は`Accepted: False`、
`reason: Invalid`に陥り、コントローラーのログには`TargetGroup port is empty. When
using Instance targets, your service must be of type 'NodePort' or
'LoadBalancer'`が繰り返し現れます(検証済み)。Ingressの世界では、これは
`alb.ingress.kubernetes.io/target-type: ip`というアノテーションで解決していまし
た。Gateway APIでは、アノテーションの代わりに専用の型付きオブジェクトがあり、それ
は自分のServiceのnamespaceに置かれていなければなりません:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: frontend
  namespace: eks-128
spec:
  targetReference:
    name: frontend
  defaultConfiguration:
    targetType: ip
EOF
```

アドレスを待ち、AWS CLI経由でこれが本当にALBであることを確認します:

```bash
for i in $(seq 1 30); do
  ADDR=$(kubectl get gateway web -n eks-128 -o jsonpath='{.status.addresses[0].value}')
  [[ -n "$ADDR" ]] && break
  sleep 10
done
echo "gateway address: $ADDR"

LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${ADDR}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/3
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/3/alb.txt
cat /var/work/tests/artifacts/3/alb.txt
```

出力の中で`Type`は`application`であるべきです - `aws-alb`クラスの`Gateway`は、ラボ
109で`ingressClassName: alb`の`Ingress`が行っていたのと同じ方法でALBを作成しま
す。単にアノテーションの代わりに型付きリソースを使っているだけです。

残るは`Programmed: True`を待ち、トラフィックが本当に流れていることを確認することで
す。ロードバランサーは内部向け(`internal-...`)なので、リクエストはワーカーマシン
から行います - それは同じVPCの中にあります:

```bash
for i in $(seq 1 30); do
  p=$(kubectl get gateway web -n eks-128 \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
  [[ "$p" == "True" ]] && break
  sleep 10
done
kubectl get gateway web -n eks-128 -o wide

curl -s -o /dev/null -w "http=%{http_code}\n" "http://${ADDR}/"
```

`http=200`という応答は、`Programmed: True`になってから1〜2分後に届きます: まず
ALBがアクティブになり、その後ターゲットがhealth checkを通過します(ターゲットの状
態は`aws elbv2 describe-target-health`で確認できます)。

## タスク4. AWS Gateway API ControllerとVPC LatticeクラスのGateway

まず、VPC Latticeのトラフィック用にノードのSGを開きます - このルールがないと、
podはService Networkからのトラフィックを受け取れません(第28章、コントローラーの
デプロイに関するドキュメントの28.4節):

```bash
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.eu-central-1.vpc-lattice'].PrefixListId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$NODE_SG" \
  --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
```

コントローラーをセットアップします: namespace、ロールを持つServiceAccount、パラ
メータ`defaultServiceNetwork`を持つHelm chartです - コントローラーは自分でService
Network `eks-task128-mesh`を作成し、クラスタのVPCと関連付けます。Chartとイメージは
パブリックECRにあり、匿名で取得できます。`helm registry login`は必要ありません
(ワーカーのロールには`ecr-public:GetAuthorizationToken`がありませんが、これは正し
いことです - パブリックレジストリはトークンなしで読み取れます):

```bash
kubectl create namespace aws-application-networking-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gateway-api-controller
  namespace: aws-application-networking-system
  annotations:
    eks.amazonaws.com/role-arn: ${LATTICE_ROLE_ARN}
EOF

helm install gateway-api-controller \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
  --version=v1.1.0 \
  --namespace aws-application-networking-system \
  --set=serviceAccount.create=false \
  --set=defaultServiceNetwork=eks-task128-mesh \
  --set=awsRegion="${REGION}" \
  --set=awsAccountId="${ACCOUNT_ID}" \
  --set=clusterVpcId="${VPC_ID}" \
  --set=clusterName="${CLUSTER}"

kubectl rollout status deployment -n aws-application-networking-system --timeout=180s
```

最後の4つのフラグは、LBCにおける`region`と`vpcId`と同じ理由で必須ですが、症状が異
なるので覚えておく価値があります。このコントローラーのpodは通常のEC2ノード上に配置
されるため、原則としてIMDSは存在しますが、IMDSv2はhop limitが1で動作しており、pod
のネットワークnamespaceからのリクエストは拒否されます。これらのフラグがないと、コ
ントローラーは即座に`init config failed: vpcId is not specified: EC2MetadataError
... status code: 401`で落ちます(検証済み)。まさにこのhop limitが第10章と第19章で
扱われています: それはノードロールの認証情報をpodから守っていますが、同時に
メタデータをあてにするあらゆるコントローラーを壊してしまいます。

VPC Lattice用の`GatewayClass`と`Gateway`自体を作成します:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: amazon-vpc-lattice
spec:
  controllerName: application-networking.k8s.aws/gateway-api-controller
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eks-task128-mesh
  namespace: eks-128
spec:
  gatewayClassName: amazon-vpc-lattice
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway eks-task128-mesh -n eks-128 -o wide
```

ここでの`Gateway`の名前は任意ではなく、これがこのタスクの主な落とし穴です。VPC
Latticeのコントローラーは、`defaultServiceNetwork`の値ではなく、`Gateway`オブジェ
クトの名前でService Networkを検索します。`Gateway`に`mesh`という名前を付けてしまう
と、それは永久に`Programmed: False`のままとなり、`VPC Lattice Service Network not
found`というメッセージが出ます。なぜなら、このアカウントのネットワークの名前は
`eks-task128-mesh`だからです(検証済み: 2つの`Gateway`を並べて配置し、名前が一致す
る方は`Programmed: True`でメッセージにネットワークのARNが表示され、一致しない方は
`not found`になります)。ここから次の規則が導かれます: `Gateway`の名前 = Service
Networkの名前。

`amazon-vpc-lattice`クラスの`Gateway`は、VPC LatticeのService Networkに写像されま
す: これはクラスタ内のサービス間のeast-west接続であり、`aws-alb`のような外部からの
入口ではありません(第28章、28.5節)。

## タスク5. 症状: ReferenceGrantのないHTTPRoute

隣接するnamespaceにbackendを立ち上げます:

```bash
kubectl create deployment backend --image=viktoruj/ping_pong:latest \
  --replicas=1 -n eks-128-backend
kubectl rollout status deployment/backend -n eks-128-backend
kubectl expose deployment backend -n eks-128-backend --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: backend
  namespace: eks-128-backend
spec:
  targetReference:
    name: backend
  defaultConfiguration:
    targetType: ip
EOF
```

`TargetGroupConfiguration`が必要な理由はタスク3と同じで、同時に所有権の分離も示し
ています: このオブジェクトはルートの隣ではなく、自分のServiceの所有者のnamespace
に置かれます。

ルート`rates`は`eks-128`に存在しますが、`eks-128-backend`にあるServiceを参照しま
す。親は`aws-alb`クラスの`Gateway` `web`です:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /rates
      backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF
```

同じルートですが、今度は`amazon-vpc-lattice`クラスの`Gateway`に対して - これは対照
実験で、このタスクの結論に必要です:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates-lattice
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: eks-task128-mesh
      sectionName: http
  rules:
    - backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF

sleep 25
mkdir -p /var/work/tests/artifacts/5
{
  echo "rates status=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates reason=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
  echo "rates message=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].message}')"
  echo "rates-lattice status=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates-lattice reason=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
} > /var/work/tests/artifacts/5/refnotpermitted.txt
cat /var/work/tests/artifacts/5/refnotpermitted.txt
```

`kubectl -o yaml | grep -A...`は使いません: CRDオブジェクト(unstructured)では、
conditionのフィールドはアルファベット順にシリアライズされます(`reason`、`status`
が`type`より先に来ます)。そのため、必要なconditionを`jsonpath`経由で直接取り出す
方が確実です。

`namespace`フィールドを持つ`backendRefs`は、別のnamespaceにあるServiceを参照しま
す - このような参照はデフォルトで禁止されています。これは、`eks-128`の開発者が、そ
の所有者の許可なしに他人のサービスへトラフィックを向けることができないようにするた
めです(第28章、28.2節)。ルート`rates`の`ResolvedRefs`条件は`status: "False"`、
`reason: RefNotPermitted`、メッセージは`No explicit ReferenceGrant exists to
allow the reference.`になります。

そして、まさにこの対照実験が示す結果がこれです: `rates-lattice`の条件は、
`eks-128-backend`にまだ`ReferenceGrant`がまったく存在していないにもかかわらず、即
座に`ResolvedRefs: True`になります(検証済み)。`ReferenceGrant`というルールは
Gateway APIの仕様の一部ですが、それを遵守するのはAPIサーバーではなく実装です:
AWS Load Balancer Controllerはこれをチェックしますが、バージョンv1.1.0のVPC
Latticeのコントローラーはチェックしません。ここから実務上の結論が得られます: 同じ
YAMLでも、Gateway APIの2つの実装ではチーム間の信頼境界が異なり、コントローラーの挙
動を確認した場所でのみ`ReferenceGrant`を保護として信頼できます。

## タスク6. 修正: ReferenceGrantがクロスnamespace参照を許可する

`ReferenceGrant`は**対象の**backendの所有者、つまりnamespace
`eks-128-backend`が作成します。参照する側ではありません:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-from-eks-128
  namespace: eks-128-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: eks-128
  to:
    - group: ""
      kind: Service
EOF

sleep 15
mkdir -p /var/work/tests/artifacts/6
{
  echo "ResolvedRefs status=$(kubectl get httproute rates -n eks-128 \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "curl /rates http=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${ADDR}/rates")"
} > /var/work/tests/artifacts/6/resolved.txt
cat /var/work/tests/artifacts/6/resolved.txt
```

アーティファクトの2行目では、ステータスではなくトラフィック自体を確認します:
`backend`podからの`http=200`は、チェーン全体が組み上がったことを意味します - ルー
トはgrantによって解決され、`ip`タイプのtarget groupが作成され、ターゲットがhealth
checkを通過しています。`ResolvedRefs`がすでに`True`なのに`curl`が`503`を返す場合
は、1分待ってください: ターゲットの登録はtarget groupが現れた後に行われます。

`ReferenceGrant`が現れた後、`rates`の`ResolvedRefs`条件は数秒で`True`に変わりま
す - コントローラーは次のreconciliationで許可された参照を再評価し、ルートは隣接す
るnamespaceの`backend`を解決し始めます。許可を出すのは対象の所有者namespaceである
ことに注意してください: `ReferenceGrant`を削除すると、ルート自体は何も変更されてい
ないのに、`RefNotPermitted`に戻ります。

## クイックチェック

```bash
check_result
```
