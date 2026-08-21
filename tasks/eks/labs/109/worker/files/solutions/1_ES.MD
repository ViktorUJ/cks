[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 - solución de referencia (Ingress a través de ALB, ACM, external-dns, Route 53)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el clúster. Terraform ya ha creado los roles IAM para LBC y external-dns, la zona
privada, y el certificado autofirmado en ACM - sus valores están escritos en
`~/lab109_hints.txt`.

```bash
cat ~/lab109_hints.txt
```

## Tarea 1. Namespace, Service y la carga de trabajo ping_pong

```bash
kubectl create namespace eks-109

kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-109
kubectl -n eks-109 set env deployment/web PORT=8080
kubectl rollout status deployment/web -n eks-109

kubectl expose deployment web -n eks-109 --port=80 --target-port=8080 --type=ClusterIP
```

## Tarea 2. ServiceAccount e instalación del AWS Load Balancer Controller

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

## Tarea 3. Ingress a través de ALB: internal, target-type ip

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

En cuanto aparezca una dirección, encuentra el ARN del balanceador y confirma mediante la
AWS CLI que es un ALB (`application`) con scheme `internal`:

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

## Tarea 4. TLS: certificado ACM, listener HTTPS, redirección

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

Ahora la salida debería mostrar un listener en `443` con `Protocol: HTTPS` y un
`CertificateArn` que coincide con `$CERT_ARN`. El listener en `80` ahora redirige a `443`
por defecto (la anotación `ssl-redirect`) en lugar de reenviar al target group.

## Tarea 5. external-dns: ALIAS y TXT en la zona privada

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

Espera a que se complete un ciclo de sincronización (hasta un minuto por defecto) y
comprueba la zona:

```bash
sleep 60
mkdir -p /var/work/tests/artifacts/5
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  > /var/work/tests/artifacts/5/dns.txt
cat /var/work/tests/artifacts/5/dns.txt
```

La salida debería contener un registro `app.eks-task109.internal` de tipo `A` (ALIAS al
ALB) y junto a él un registro TXT de propiedad con `heritage=external-dns` y
`owner=eks-task109` dentro del valor.

## Tarea 6. Diagnóstico: ingressClassName incorrecto e IngressGroup

Primero, reproduce el síntoma. El admission webhook de LBC (`vingress.elbv2.k8s.aws`)
rechaza un Ingress si `ingressClassName` apunta a un objeto `IngressClass` inexistente -
para obtener el síntoma limpio "LBC no reconcilia una clase que no le pertenece" se
necesita un `IngressClass` REAL con un controlador distinto de `ingress.k8s.aws/alb`, no
solo una cadena arbitraria:

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
# ADDRESS se queda vacío - LBC solo observa objetos IngressClass cuyo controlador es
# ingress.k8s.aws/alb, y wrong-class pertenece a un controlador distinto (inexistente).

mkdir -p /var/work/tests/artifacts/6
echo "ingressClassName: wrong-class - LBC no ve este Ingress porque solo observa" \
     "objetos cuyo IngressClass tiene controller = ingress.k8s.aws/alb. El Ingress" \
     "se queda sin dirección (ADDRESS vacío) hasta que se corrige la clase." \
     > /var/work/tests/artifacts/6/groupfix.txt
```

Ahora la corrección - la clase correcta más el mismo grupo que `web`, para que ambos
Ingress compartan un solo ALB:

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

echo "Tras la corrección: ingressClassName=alb, dirección de status=$STATUS_ADDR" \
     "coincide con la dirección de web=$WEB_ADDR - ambos Ingress comparten un ALB a" \
     "través del group.name del IngressGroup." \
     >> /var/work/tests/artifacts/6/groupfix.txt
cat /var/work/tests/artifacts/6/groupfix.txt
```

## Comprobación rápida

```bash
check_result
```
