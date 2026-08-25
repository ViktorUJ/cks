[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 - Referenzlösung (Ingress über ALB, ACM, external-dns, Route 53)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl ist bereits für
den Cluster konfiguriert. Terraform hat bereits die IAM-Rollen für LBC und external-dns,
die private Hosted Zone und das selbstsignierte Zertifikat in ACM erstellt - ihre Werte
sind in `~/lab109_hints.txt` hinterlegt.

```bash
cat ~/lab109_hints.txt
```

## Aufgabe 1. Namespace, Service und die ping_pong-Workload

```bash
kubectl create namespace eks-109

kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-109
kubectl -n eks-109 set env deployment/web PORT=8080
kubectl rollout status deployment/web -n eks-109

kubectl expose deployment web -n eks-109 --port=80 --target-port=8080 --type=ClusterIP
```

## Aufgabe 2. ServiceAccount und Installation des AWS Load Balancer Controllers

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

## Aufgabe 3. Ingress über ALB: internal, target-type ip

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

Sobald eine Adresse erscheint, ermitteln Sie den ARN des Load Balancers und bestätigen Sie
über die AWS CLI, dass es sich um einen ALB (`application`) mit Scheme `internal`
handelt:

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

## Aufgabe 4. TLS: ACM-Zertifikat, HTTPS-Listener, Redirect

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

Die Ausgabe sollte jetzt einen Listener auf `443` mit `Protocol: HTTPS` und einem
`CertificateArn` zeigen, der zu `$CERT_ARN` passt. Der Listener auf `80` leitet nun
standardmäßig auf `443` weiter (die Annotation `ssl-redirect`), statt an die Target Group
weiterzuleiten.

## Aufgabe 5. external-dns: ALIAS und TXT in der privaten Hosted Zone

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

Warten Sie auf einen Sync-Zyklus (standardmäßig bis zu einer Minute) und prüfen Sie die
Zone:

```bash
sleep 60
mkdir -p /var/work/tests/artifacts/5
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  > /var/work/tests/artifacts/5/dns.txt
cat /var/work/tests/artifacts/5/dns.txt
```

Die Ausgabe sollte einen Eintrag `app.eks-task109.internal` vom Typ `A` (ALIAS auf den
ALB) enthalten und daneben einen Ownership-TXT-Eintrag mit `heritage=external-dns` und
`owner=eks-task109` im Wert.

## Aufgabe 6. Diagnose: falsche ingressClassName und IngressGroup

Reproduzieren Sie zuerst das Symptom. Der Admission-Webhook des LBC
(`vingress.elbv2.k8s.aws`) lehnt einen Ingress ab, wenn `ingressClassName` auf ein nicht
existierendes `IngressClass`-Objekt zeigt - um das saubere Symptom "LBC reconciled keine
Klasse, die er nicht besitzt" zu erhalten, brauchen Sie eine ECHTE `IngressClass` mit
einem anderen Controller als `ingress.k8s.aws/alb`, nicht nur eine beliebige
Zeichenkette:

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
# ADDRESS bleibt leer - LBC beobachtet nur IngressClass-Objekte, deren Controller
# ingress.k8s.aws/alb ist, und wrong-class gehört zu einem anderen (nicht existierenden) Controller.

mkdir -p /var/work/tests/artifacts/6
echo "ingressClassName: wrong-class - LBC sieht diesen Ingress nicht, weil er nur" \
     "Objekte beobachtet, deren IngressClass den Controller ingress.k8s.aws/alb hat." \
     "Der Ingress bleibt ohne Adresse (ADDRESS ist leer), bis die Klasse korrigiert wird." \
     > /var/work/tests/artifacts/6/groupfix.txt
```

Jetzt die Behebung - die richtige Klasse plus dieselbe Gruppe wie `web`, damit sich beide
Ingresses einen ALB teilen:

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

echo "Nach der Behebung: ingressClassName=alb, status address=$STATUS_ADDR entspricht" \
     "web address=$WEB_ADDR - beide Ingresses teilen sich einen ALB über die" \
     "IngressGroup group.name." \
     >> /var/work/tests/artifacts/6/groupfix.txt
cat /var/work/tests/artifacts/6/groupfix.txt
```

## Schnellprüfung

```bash
check_result
```
