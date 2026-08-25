[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 109 - 參考解答(透過 ALB 的 Ingress、ACM、external-dns、Route 53)

所有命令都在工作機上透過 SSH 執行。kubectl 已經配置好指向集群。Terraform 已經建立了
LBC 和 external-dns 用的 IAM 角色、私有 hosted zone,以及 ACM 中的自我簽署憑證 - 它們
的值都寫在 `~/lab109_hints.txt` 中。

```bash
cat ~/lab109_hints.txt
```

## 任務 1. Namespace、Service 與 ping_pong 負載

```bash
kubectl create namespace eks-109

kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-109
kubectl -n eks-109 set env deployment/web PORT=8080
kubectl rollout status deployment/web -n eks-109

kubectl expose deployment web -n eks-109 --port=80 --target-port=8080 --type=ClusterIP
```

## 任務 2. ServiceAccount 與安裝 AWS Load Balancer Controller

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

## 任務 3. 透過 ALB 的 Ingress:internal,target-type ip

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

一旦出現位址,就找出 load balancer 的 ARN,並透過 AWS CLI 確認它是一個 scheme 為
`internal` 的 ALB(`application`):

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

## 任務 4. TLS:ACM 憑證、HTTPS listener、redirect

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

輸出中現在應該有一個 `443` 上的 listener,`Protocol: HTTPS`,且 `CertificateArn` 與
`$CERT_ARN` 一致。`80` 上的 listener 現在預設會 redirect 到 `443`(`ssl-redirect`
annotation),而不是轉發到 target group。

## 任務 5. external-dns:私有 hosted zone 中的 ALIAS 與 TXT

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

等待一次同步週期(預設最多一分鐘),然後檢查該 zone:

```bash
sleep 60
mkdir -p /var/work/tests/artifacts/5
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  > /var/work/tests/artifacts/5/dns.txt
cat /var/work/tests/artifacts/5/dns.txt
```

輸出中應該包含一筆類型為 `A`(指向 ALB 的 ALIAS)的 `app.eks-task109.internal` 記錄,
以及旁邊一筆值中帶有 `heritage=external-dns` 和 `owner=eks-task109` 的所有權 TXT 記錄。

## 任務 6. 診斷:錯誤的 ingressClassName 與 IngressGroup

首先重現這個症狀。LBC 的 admission webhook(`vingress.elbv2.k8s.aws`)會拒絕
`ingressClassName` 指向不存在的 `IngressClass` 物件的 Ingress - 要得到「LBC 不會協調它
不擁有的類別」這個乾淨的症狀,需要一個真實的 `IngressClass`,controller 不是
`ingress.k8s.aws/alb`,而不能只是隨便一個字串:

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
# ADDRESS 一直是空的 - LBC 只監看 controller 為 ingress.k8s.aws/alb 的
# IngressClass 物件,而 wrong-class 屬於另一個(不存在的)controller。

mkdir -p /var/work/tests/artifacts/6
echo "ingressClassName: wrong-class - LBC 看不到這個 Ingress,因為它只監看" \
     "IngressClass 的 controller = ingress.k8s.aws/alb 的物件。這個 Ingress 會" \
     "一直沒有位址(ADDRESS 為空),直到類別被修復為止。" \
     > /var/work/tests/artifacts/6/groupfix.txt
```

現在進行修復 - 正確的類別加上與 `web` 相同的 group,讓兩個 Ingress 共用一個 ALB:

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

echo "修復後:ingressClassName=alb,status 的位址=$STATUS_ADDR 與 web 的位址" \
     "=$WEB_ADDR 一致 - 兩個 Ingress 透過 IngressGroup 的 group.name 共用同一個" \
     "ALB。" \
     >> /var/work/tests/artifacts/6/groupfix.txt
cat /var/work/tests/artifacts/6/groupfix.txt
```

## 快速檢查

```bash
check_result
```
