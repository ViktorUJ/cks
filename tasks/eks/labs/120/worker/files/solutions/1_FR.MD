[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 120 - solution de référence (pannes réseau, targets unhealthy du load balancer)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà
configuré pour le cluster. Terraform a déjà créé le security group « cassé »
(composant `eks_network_break_demo`) et un rôle IRSA pour l'AWS Load Balancer
Controller (`eks_lbc_irsa`) - les noms et ids sont dans `~/lab120_hints.txt`.

```bash
cat ~/lab120_hints.txt
export SG_ID=$(grep '^broken_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab120_hints.txt | awk '{print $3}')
export CLUSTER=$(grep '^cluster_name' ~/lab120_hints.txt | awk '{print $3}')
```

## Tâche 1. Namespace et charge de travail de la lab

```bash
kubectl create namespace eks-120

kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-120
kubectl rollout status deployment/api -n eks-120

kubectl expose deployment api -n eks-120 --port=80 --target-port=8080 --name=api

kubectl create deployment client --image=busybox:1.36 -n eks-120 -- sleep 3600
kubectl rollout status deployment/client -n eks-120
```

## Tâche 2. Connectivité de base et diagnostic SG

```bash
CLIENT_POD=$(kubectl get pod -n eks-120 -l app=client -o jsonpath='{.items[0].metadata.name}')

mkdir -p /var/work/tests/artifacts/2
kubectl exec -n eks-120 "$CLIENT_POD" -- \
  wget -qO- --timeout=5 http://api.eks-120.svc.cluster.local \
  > /var/work/tests/artifacts/2/connectivity.txt
cat /var/work/tests/artifacts/2/connectivity.txt
```

La connectivité fonctionne bien ici : le node SG autorise le trafic entre les
pods du cluster, et les SG sont stateful, donc la réponse à cette requête passe
d'elle-même (chapitre 46.3). Regardons quels SG sont réellement attachés à
l'ENI du pod `api` :

```bash
API_IP=$(kubectl get pod -n eks-120 -l app=api -o jsonpath='{.items[0].status.podIP}')

Le filtre utilisé pour trouver l'ENI est important. Avec VPC CNI, l'IP du pod
est une adresse **secondaire** sur l'ENI du node, donc le filtre
`private-ip-address` (qui regarde l'adresse primaire de l'interface) renverra
`null`. Il faut utiliser `addresses.private-ip-address`, qui recherche parmi
toutes les adresses de l'interface :

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=addresses.private-ip-address,Values=${API_IP}" \
  --query 'NetworkInterfaces[0].Groups' \
  > /var/work/tests/artifacts/2/api_sg.txt
cat /var/work/tests/artifacts/2/api_sg.txt
```

## Tâche 3. Installation de l'AWS Load Balancer Controller

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

Un détail important de cet environnement : le namespace `kube-system` relève
du profil Fargate, donc les pods du contrôleur tournent sur Fargate, et
Fargate n'a **pas d'IMDS**. Sans IMDS, le contrôleur ne peut pas déterminer la
région et le VPC par lui-même et échoue avec `failed to get VPC ID: ...
ec2imds ... context deadline exceeded`. On définit donc `region` et `vpcId`
explicitement :

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

## Tâche 4. Symptôme : NLB avec des targets unhealthy

On définit le SG « cassé » comme security group propre du balancer. Dès qu'un
SG est spécifié explicitement via l'annotation, le LBC arrête d'ajouter pour
nous la règle inbound manquante au node SG - c'est exactement la panne
(chapitre 46.6) :

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

On attend l'adresse externe, on trouve le target group, et on vérifie l'état
de santé des targets :

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

Toutes les targets sont `unhealthy` - le SG du balancer ne laisse pas passer
le health check vers le node SG, et donc il n'atteint jamais le pod `api` non
plus.

## Tâche 5. Diagnostic : quel SG bloque le health check

```bash
aws ec2 describe-security-groups --group-ids "$SG_ID" \
  --query 'SecurityGroups[0].IpPermissions'
```

La liste vide le confirme : le SG du balancer n'a pas une seule règle inbound.

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnosis.txt <<EOF
Le security group du balancer (${SG_ID}) est assigné à api-lb via l'annotation
aws-load-balancer-security-groups et ne contient aucune règle inbound. Le
health check du NLB arrive comme une nouvelle connexion TCP depuis le security
group du balancer vers le node security group (${NODE_SG}) sur le port
8080 de l'application. Le node security group n'autorise pas le trafic
inbound depuis le security group du balancer sur ce port, donc le health
check échoue et les targets restent unhealthy (chapitre 46.6).
EOF
cat /var/work/tests/artifacts/5/diagnosis.txt
```

## Tâche 6. Correction : authorize-security-group-ingress, targets healthy

Deux règles : autoriser le health check et le trafic applicatif depuis le SG
du balancer vers le node SG, et ouvrir le listener du NLB pour les clients sur
le port 80 :

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

On attend que les targets deviennent `healthy` (généralement 1-2 minutes) et
on vérifie avec curl :

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

## Tâche 7. Le DNS fonctionne : une vérification contrastante

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl run dnstest --image=busybox:1.36 --rm -i --restart=Never -- \
  sh -c 'nslookup kubernetes.default.svc.cluster.local; nslookup example.com' \
  > /var/work/tests/artifacts/7/dns.txt
cat /var/work/tests/artifacts/7/dns.txt
```

On interroge le nom interne par son FQDN complet. Le nom court
`kubernetes.default` via `nslookup` depuis busybox renvoie `NXDOMAIN` : ce
resolver n'ajoute pas les search domains de `/etc/resolv.conf` comme le fait
un client normal, et cette réponse est facile à confondre avec une panne DNS
qui n'existe pas.

Les deux noms se résolvent bien (`kubernetes.default.svc.cluster.local` vers
l'adresse du service `kubernetes`, `example.com` vers des adresses externes) -
le DNS n'est pas la source du problème dans cette lab (chapitres 46.5, 46.7),
contrairement au security group des tâches 4-6.

## Tâche 8. Checklist finale : symptôme - cause probable - quoi vérifier

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/summary.txt <<EOF
Symptôme : les targets du target group NLB sont unhealthy, le service api-lb
renvoie 503.
Cause probable : le security group du balancer n'autorise pas le trafic
inbound vers le node SG sur le port du health check (chapitre 46.6).
Quoi vérifier : aws elbv2 describe-target-health --target-group-arn <arn>
montrera TargetHealth.Reason=Target.FailedHealthChecks, et aws ec2
describe-security-groups confirmera que le SG du balancer n'a aucune règle
inbound.
EOF
cat /var/work/tests/artifacts/8/summary.txt
```

## Vérification rapide

```bash
check_result
```
