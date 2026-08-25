[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 - solution de référence (Ingress via ALB, ACM, external-dns, Route 53)

Toutes les commandes s'exécutent sur la machine de travail via SSH. kubectl est déjà
configuré pour le cluster. Terraform a déjà créé les rôles IAM pour LBC et external-dns,
la zone hébergée privée, et le certificat auto-signé dans ACM - leurs valeurs sont
écrites dans `~/lab109_hints.txt`.

```bash
cat ~/lab109_hints.txt
```

## Tâche 1. Namespace, Service et la charge de travail ping_pong

```bash
kubectl create namespace eks-109

kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-109
kubectl -n eks-109 set env deployment/web PORT=8080
kubectl rollout status deployment/web -n eks-109

kubectl expose deployment web -n eks-109 --port=80 --target-port=8080 --type=ClusterIP
```

## Tâche 2. ServiceAccount et installation de l'AWS Load Balancer Controller

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

## Tâche 3. Ingress via ALB : internal, target-type ip

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

Dès qu'une adresse apparaît, trouvez l'ARN du load balancer et confirmez via l'AWS CLI
qu'il s'agit bien d'un ALB (`application`) avec le schéma `internal` :

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

## Tâche 4. TLS : certificat ACM, listener HTTPS, redirection

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

La sortie doit maintenant montrer un listener sur `443` avec `Protocol: HTTPS` et un
`CertificateArn` correspondant à `$CERT_ARN`. Le listener sur `80` redirige désormais par
défaut vers `443` (l'annotation `ssl-redirect`) au lieu de transmettre vers le target
group.

## Tâche 5. external-dns : ALIAS et TXT dans la zone hébergée privée

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

Attendez un cycle de synchronisation (jusqu'à une minute par défaut) et vérifiez la zone :

```bash
sleep 60
mkdir -p /var/work/tests/artifacts/5
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  > /var/work/tests/artifacts/5/dns.txt
cat /var/work/tests/artifacts/5/dns.txt
```

La sortie doit contenir un enregistrement `app.eks-task109.internal` de type `A` (ALIAS
vers l'ALB) et à côté un enregistrement TXT de propriété avec `heritage=external-dns` et
`owner=eks-task109` dans la valeur.

## Tâche 6. Diagnostic : ingressClassName erroné et IngressGroup

D'abord, reproduisez le symptôme. Le webhook d'admission de LBC (`vingress.elbv2.k8s.aws`)
rejette un Ingress si `ingressClassName` pointe vers un objet `IngressClass` inexistant -
pour obtenir le symptôme propre « LBC ne réconcilie pas une classe qu'il ne possède pas »,
il faut un VRAI `IngressClass` avec un controller autre que `ingress.k8s.aws/alb`, pas
juste une chaîne arbitraire :

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
# ADDRESS reste vide - LBC ne surveille que les objets IngressClass dont le controller
# est ingress.k8s.aws/alb, et wrong-class appartient à un controller différent (inexistant).

mkdir -p /var/work/tests/artifacts/6
echo "ingressClassName: wrong-class - LBC ne voit pas cet Ingress car il ne surveille" \
     "que les objets dont l'IngressClass a controller = ingress.k8s.aws/alb. L'Ingress" \
     "reste sans adresse (ADDRESS est vide) jusqu'à ce que la classe soit corrigée." \
     > /var/work/tests/artifacts/6/groupfix.txt
```

Maintenant la correction - la bonne classe plus le même groupe que `web`, afin que les
deux Ingress partagent un seul ALB :

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

echo "Après la correction : ingressClassName=alb, adresse de status=$STATUS_ADDR" \
     "correspond à l'adresse de web=$WEB_ADDR - les deux Ingress partagent un seul ALB" \
     "via l'IngressGroup group.name." \
     >> /var/work/tests/artifacts/6/groupfix.txt
cat /var/work/tests/artifacts/6/groupfix.txt
```

## Vérification rapide

```bash
check_result
```
