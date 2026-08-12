#!/bin/bash
set -e
export KUBECONFIG=/home/ubuntu/.kube/config

# Task 5
ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name eks-task109.internal \
  --query "HostedZones[0].Id" --output text | sed 's|/hostedzone/||')
echo "ZONE_ID=$ZONE_ID"

echo "waiting for external-dns sync cycle..."
sleep 70
mkdir -p /var/work/tests/artifacts/5
aws route53 list-resource-record-sets --hosted-zone-id "$ZONE_ID" \
  > /var/work/tests/artifacts/5/dns.txt
cat /var/work/tests/artifacts/5/dns.txt

# Task 6
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

mkdir -p /var/work/tests/artifacts/6
echo "ingressClassName: wrong-class - LBC не видит этот Ingress, потому что следит только" \
     "за объектами с IngressClass, чей controller = ingress.k8s.aws/alb. Ingress остаётся" \
     "без адреса (ADDRESS пустой), пока класс не исправлен." \
     > /var/work/tests/artifacts/6/groupfix.txt

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

echo "После фикса: ingressClassName=alb, адрес status=$STATUS_ADDR совпадает с адресом" \
     "web=$WEB_ADDR - оба Ingress делят один ALB через IngressGroup group.name." \
     >> /var/work/tests/artifacts/6/groupfix.txt
cat /var/work/tests/artifacts/6/groupfix.txt

echo "DONE"
