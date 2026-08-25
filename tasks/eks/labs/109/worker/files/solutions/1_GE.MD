[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 109 - ეტალონური გადაწყვეტა (Ingress ALB-ის მეშვეობით, ACM, external-dns, Route 53)

ყველა ბრძანება სრულდება worker მანქანაზე SSH-ის მეშვეობით. kubectl უკვე
კონფიგურირებულია კლასტერზე. Terraform-ს უკვე შექმნილი აქვს IAM-როლები LBC-სთვის და
external-dns-სთვის, პრივატული hosted zone და self-signed სერტიფიკატი ACM-ში - მათი
მნიშვნელობები ჩაწერილია ფაილში `~/lab109_hints.txt`.

```bash
cat ~/lab109_hints.txt
```

## დავალება 1. Namespace, Service და ping_pong დატვირთვა

```bash
kubectl create namespace eks-109

kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-109
kubectl -n eks-109 set env deployment/web PORT=8080
kubectl rollout status deployment/web -n eks-109

kubectl expose deployment web -n eks-109 --port=80 --target-port=8080 --type=ClusterIP
```

## დავალება 2. ServiceAccount და AWS Load Balancer Controller-ის დაინსტალირება

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

## დავალება 3. Ingress ALB-ის მეშვეობით: internal, target-type ip

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

როგორც კი გამოჩნდება მისამართი, მოძებნეთ load balancer-ის ARN და AWS CLI-ის
მეშვეობით დაადასტურეთ, რომ ეს არის ALB (`application`) სქემით `internal`:

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

## დავალება 4. TLS: ACM სერტიფიკატი, HTTPS listener, redirect

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

ახლა output-ში უნდა გამოჩნდეს listener `443`-ზე `Protocol: HTTPS`-ითა და
`CertificateArn`-ით, რომელიც ემთხვევა `$CERT_ARN`-ს. Listener `80`-ზე ახლა
ნაგულისხმევად გადამისამართებს `443`-ზე (`ssl-redirect` ანოტაცია) target group-ზე
გადაცემის ნაცვლად.

## დავალება 5. external-dns: ALIAS და TXT პრივატულ hosted zone-ში

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

დაელოდეთ სინქრონიზაციის ციკლს (ნაგულისხმევად არა უმეტეს ერთი წუთის) და შეამოწმეთ
ზონა:

```bash
sleep 60
mkdir -p /var/work/tests/artifacts/5
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  > /var/work/tests/artifacts/5/dns.txt
cat /var/work/tests/artifacts/5/dns.txt
```

Output-ში უნდა იყოს ჩანაწერი `app.eks-task109.internal` ტიპით `A` (ALIAS ALB-ზე)
და მის გვერდით მფლობელობის TXT ჩანაწერი მნიშვნელობის შიგნით `heritage=external-dns`
და `owner=eks-task109`-ით.

## დავალება 6. დიაგნოსტიკა: არასწორი ingressClassName და IngressGroup

პირველ ეტაპზე გამოვიმუშაოთ სიმპტომი. LBC-ის admission webhook
(`vingress.elbv2.k8s.aws`) უკუაგდებს Ingress-ს, თუ `ingressClassName` მიუთითებს
არარსებულ `IngressClass` ობიექტზე - სუფთა სიმპტომის "LBC არ ერეკონსილირებს კლასს,
რომელსაც არ ეკუთვნის" მისაღებად საჭიროა ნამდვილი `IngressClass` კონტროლერით,
რომელიც განსხვავდება `ingress.k8s.aws/alb`-სგან, არა უბრალო თხზული სტრიქონი:

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
# ADDRESS ცარიელი რჩება - LBC აკვირდება მხოლოდ იმ IngressClass ობიექტებს, რომელთა
# კონტროლერია ingress.k8s.aws/alb, ხოლო wrong-class სხვა (არარსებულ) კონტროლერს ეკუთვნის.

mkdir -p /var/work/tests/artifacts/6
echo "ingressClassName: wrong-class - LBC-ს ეს Ingress არ ეხედება, რადგან ის" \
     "აკვირდება მხოლოდ ობიექტებს, რომელთა IngressClass-ს აქვს controller =" \
     "ingress.k8s.aws/alb. Ingress მისამართის გარეშე რჩება (ADDRESS ცარიელია)," \
     "სანამ კლასი არ გამოსწორდება." \
     > /var/work/tests/artifacts/6/groupfix.txt
```

ახლა გამოსწორება - სწორი კლასი პლუს იგივე ჯგუფი, რაც `web`-ს აქვს, ისე რომ ორივე
Ingress-მა ერთი ALB გაიზიაროს:

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

echo "გამოსწორების შემდეგ: ingressClassName=alb, status-ის მისამართი=$STATUS_ADDR" \
     "ემთხვევა web-ის მისამართს=$WEB_ADDR - ორივე Ingress იზიარებს ერთ ALB-ს" \
     "IngressGroup-ის group.name-ის მეშვეობით." \
     >> /var/work/tests/artifacts/6/groupfix.txt
cat /var/work/tests/artifacts/6/groupfix.txt
```

## სწრაფი გადამოწმება

```bash
check_result
```
