[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 109 - 参考解答(ALB 経由の Ingress、ACM、external-dns、Route 53)

すべてのコマンドは SSH 経由でワーカーマシン上で実行します。kubectl は既にクラスタ向けに
設定されています。Terraform は LBC と external-dns 用の IAM ロール、プライベート
hosted zone、ACM の自己署名証明書を既に作成しています - それらの値は
`~/lab109_hints.txt` に書かれています。

```bash
cat ~/lab109_hints.txt
```

## タスク 1. Namespace、Service、ping_pong ワークロード

```bash
kubectl create namespace eks-109

kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-109
kubectl -n eks-109 set env deployment/web PORT=8080
kubectl rollout status deployment/web -n eks-109

kubectl expose deployment web -n eks-109 --port=80 --target-port=8080 --type=ClusterIP
```

## タスク 2. ServiceAccount と AWS Load Balancer Controller のインストール

```bash
LBC_ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text)
echo "$LBC_ROLE_ARN"

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

CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's/.*\///')
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

## タスク 3. ALB 経由の Ingress: internal、target-type ip

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: eks-109
  annotations:
    alb.ingress.kubernetes.io/scheme: internal
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/group.name: eks-task109-web
spec:
  ingressClassName: alb
  rules:
    - host: app.eks-task109.internal
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF

kubectl get ingress web -n eks-109 -w
```

アドレスが現れたらすぐに、ロードバランサの ARN を見つけ、AWS CLI で `application` 型で
スキームが `internal` の ALB であることを確認します:

```bash
HOSTNAME=$(kubectl get ingress web -n eks-109 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${HOSTNAME}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/3
{
  aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN"
  aws elbv2 describe-listeners --load-balancer-arn "$LB_ARN"
} > /var/work/tests/artifacts/3/alb.txt
cat /var/work/tests/artifacts/3/alb.txt
```

## タスク 4. TLS: ACM 証明書、HTTPS リスナー、リダイレクト

```bash
CERT_ARN=$(aws acm list-certificates \
  --query "CertificateSummaryList[?DomainName=='app.eks-task109.internal'].CertificateArn" \
  --output text)
echo "$CERT_ARN"

kubectl annotate ingress web -n eks-109 --overwrite \
  alb.ingress.kubernetes.io/certificate-arn="${CERT_ARN}" \
  alb.ingress.kubernetes.io/listen-ports='[{"HTTP": 80}, {"HTTPS": 443}]' \
  alb.ingress.kubernetes.io/ssl-redirect='443'

kubectl patch ingress web -n eks-109 --type merge -p '
spec:
  tls:
    - hosts: ["app.eks-task109.internal"]
'

sleep 20
mkdir -p /var/work/tests/artifacts/4
aws elbv2 describe-listeners --load-balancer-arn "$LB_ARN" \
  > /var/work/tests/artifacts/4/https.txt
cat /var/work/tests/artifacts/4/https.txt
```

出力には、`443` 上に `Protocol: HTTPS` を持ち、`$CERT_ARN` と一致する `CertificateArn`
を持つリスナーが表示されるはずです。`80` 番のリスナーは、デフォルトでは(`ssl-redirect`
annotation により)ターゲットグループに転送する代わりに `443` へリダイレクトするように
なります。

## タスク 5. external-dns: プライベート hosted zone 内の ALIAS と TXT

```bash
EXTDNS_ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'extdns-irsa')].Arn" --output text)
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name eks-task109.internal \
  --query "HostedZones[0].Id" --output text | sed 's|/hostedzone/||')
echo "$EXTDNS_ROLE_ARN / $ZONE_ID"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${EXTDNS_ROLE_ARN}
EOF

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

helm install external-dns external-dns/external-dns \
  -n kube-system \
  --set provider.name=aws \
  --set policy=upsert-only \
  --set registry=txt \
  --set txtOwnerId=eks-task109 \
  --set domainFilters[0]=eks-task109.internal \
  --set sources[0]=ingress \
  --set extraArgs.aws-zone-type=private \
  --set serviceAccount.create=false \
  --set serviceAccount.name=external-dns

kubectl rollout status deployment/external-dns -n kube-system
```

同期サイクルを待ち(デフォルトで最大 1 分)、ゾーンを確認します:

```bash
sleep 60
mkdir -p /var/work/tests/artifacts/5
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  > /var/work/tests/artifacts/5/dns.txt
cat /var/work/tests/artifacts/5/dns.txt
```

出力には、`A` 型(ALB への ALIAS)の `app.eks-task109.internal` レコードと、その隣に
値の中に `heritage=external-dns` と `owner=eks-task109` を含む所有権 TXT レコードが
含まれるはずです。

## タスク 6. 診断: 誤った ingressClassName と IngressGroup

まず、症状を再現します。LBC の admission webhook(`vingress.elbv2.k8s.aws`)は、
`ingressClassName` が存在しない `IngressClass` オブジェクトを指す Ingress を拒否します
- 「LBC が自分の所有していないクラスを reconcile しない」というきれいな症状を得るには、
単なる任意の文字列ではなく、`ingress.k8s.aws/alb` 以外のコントローラを持つ実在する
`IngressClass` が必要です:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: wrong-class
spec:
  controller: example.com/not-alb
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: status
  namespace: eks-109
spec:
  ingressClassName: wrong-class
  rules:
    - http:
        paths:
          - path: /status
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
EOF

sleep 15
kubectl get ingress status -n eks-109
# ADDRESS は空のままになる - LBC は、controller が ingress.k8s.aws/alb である
# IngressClass オブジェクトのみを監視しており、wrong-class は別の(存在しない)
# コントローラに属しているため。

mkdir -p /var/work/tests/artifacts/6
echo "ingressClassName: wrong-class - LBC は controller = ingress.k8s.aws/alb を持つ" \
     "IngressClass のオブジェクトしか監視していないため、この Ingress を認識しない。" \
     "クラスが修正されるまで、この Ingress はアドレスを持たないまま(ADDRESS が空の" \
     "まま)になる。" \
     > /var/work/tests/artifacts/6/groupfix.txt
```

次に修正します - 正しいクラスと、`web` と同じグループを設定し、両方の Ingress が 1 つ
の ALB を共有するようにします:

```bash
kubectl patch ingress status -n eks-109 --type merge -p '
spec:
  ingressClassName: alb
'
kubectl annotate ingress status -n eks-109 --overwrite \
  alb.ingress.kubernetes.io/scheme=internal \
  alb.ingress.kubernetes.io/target-type=ip \
  alb.ingress.kubernetes.io/group.name=eks-task109-web \
  alb.ingress.kubernetes.io/group.order='10'

sleep 20
STATUS_ADDR=$(kubectl get ingress status -n eks-109 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
WEB_ADDR=$(kubectl get ingress web -n eks-109 \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "修正後: ingressClassName=alb、status のアドレス=$STATUS_ADDR は web のアドレス" \
     "=$WEB_ADDR と一致する - 両方の Ingress は IngressGroup の group.name を通じて" \
     "1 つの ALB を共有している。" \
     >> /var/work/tests/artifacts/6/groupfix.txt
cat /var/work/tests/artifacts/6/groupfix.txt
```

## クイックチェック

```bash
check_result
```
