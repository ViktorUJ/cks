[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 - solution de référence (AWS Load Balancer Controller : NLB pour un Service)

Toutes les commandes s'exécutent sur la machine de travail via SSH. kubectl est déjà
configuré pour le cluster. Terraform a déjà créé le rôle IAM pour le contrôleur (composant
`eks_lbc_irsa`, module `eks_v2_lbc_irsa`) - il ne reste plus qu'à récupérer son ARN et à
installer le contrôleur lui-même.

## Tâche 1. Namespace `eks-108`

```bash
kubectl create namespace eks-108
```

## Tâche 2. ServiceAccount et installation de l'AWS Load Balancer Controller

On récupère l'ARN du rôle créé par terraform (nom du rôle `<cluster-name>-lbc-irsa`) :

```bash
ROLE_ARN=$(aws iam list-roles \
  --query "Roles[?contains(RoleName,'lbc-irsa')].Arn" --output text)
echo "$ROLE_ARN"
```

On crée le ServiceAccount dans `kube-system` avec une annotation pointant vers ce rôle. Le
LBC s'installe via Helm avec `serviceAccount.create=false`, donc le ServiceAccount doit
exister au préalable :

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

On installe le contrôleur lui-même depuis le chart officiel :

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

Le contrôleur tourne sur Fargate (namespace `kube-system` sous le profil Fargate), et sur
Fargate il n'existe physiquement aucun instance metadata service (IMDS) EC2 - sans
`vpcId`/`region` explicites, le contrôleur essaie d'obtenir le VPC ID via IMDS et tombe en
`CrashLoopBackOff` avec une erreur du type `failed to fetch VPC ID from instance metadata:
... context deadline exceeded`. Sur des nœuds EC2 managés ces flags ne sont pas nécessaires
(IMDS y est disponible), mais sur Fargate il faut toujours les passer explicitement.

On vérifie que le contrôleur est monté et voit le rôle :

```bash
kubectl get deploy aws-load-balancer-controller -n kube-system
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml | grep role-arn
```

## Tâche 3. Deployment `web` (viktoruj/ping_pong, 2 réplicas)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-108
kubectl rollout status deployment/web -n eks-108
```

## Tâche 4. Service `web` de type LoadBalancer : NLB au lieu d'un CLB

Par défaut, l'in-tree cloud provider crée un Classic Load Balancer obsolète pour un Service
de type LoadBalancer. L'annotation `aws-load-balancer-type: external` transfère la
réconciliation à l'AWS Load Balancer Controller, qui crée un Network Load Balancer moderne :

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

On attend l'adresse externe :

```bash
kubectl get svc web -n eks-108 -w
```

On confirme via AWS CLI qu'un NLB (type `network`) a bien été créé, pas un CLB, et que le
schéma est `internet-facing` :

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

Dans la sortie, `Type` doit être `network` (NLB), et `Scheme` doit être `internet-facing`.
Si l'annotation `aws-load-balancer-type` n'existait pas, l'in-tree provider aurait créé
`Type: classic` - c'est exactement le symptôme « j'ai demandé un LoadBalancer, j'ai obtenu
un CLB » du chapitre 26.

## Tâche 5. Vérification des targets : IP des pods, pas instance ID des nœuds

`target-type: ip` enregistre dans le target group les adresses des pods fournies par VPC
CNI, et non les nœuds par `InstanceId`. On le vérifie via `describe-target-groups` et
`describe-target-health` :

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

Dans le fichier, `TargetType` doit être `ip`, et le `Target.Id` de chaque target doit être
une adresse issue de `10.10.0.0/16` (le sous-réseau du VPC de ce laboratoire), pas `i-...`
(un instance ID). C'est exactement à quoi ressemble un target group de NLB avec
`target-type: ip` : le contrôleur enregistre directement l'IP du pod, en contournant le
NodePort, ce qui supprime le saut supplémentaire via kube-proxy.

## Tâche 6. Diagnostic : réconciliation réussie face à AccessDenied

On regarde le log du contrôleur pour voir à quoi ressemble une réconciliation normale du
Service - on doit y trouver l'ARN du load balancer créé :

```bash
kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
  | grep -i 'successfully reconciled\|loadBalancerARN\|arn:aws:elasticloadbalancing' \
  | tail -n 10
```

Si le ServiceAccount n'avait pas de rôle rattaché (ou si le rôle n'avait pas les
permissions nécessaires), le contrôleur ne pourrait pas appeler l'API ELBv2 et le log
afficherait un message du type `AccessDenied: User: ... is not authorized to perform:
elasticloadbalancing:CreateLoadBalancer`, et le Service resterait en `<pending>` sans
adresse externe - car la réconciliation échoue dès le premier appel API, avant la création
du NLB.

On enregistre les deux observations dans un seul artefact :

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== Réconciliation réussie (log réel du contrôleur) ==="
  kubectl logs -n kube-system deploy/aws-load-balancer-controller --tail=200 \
    | grep -i 'successfully reconciled\|arn:aws:elasticloadbalancing'
  echo
  echo "=== Symptôme attendu sans permissions IAM (non reproduit avec le rôle actif) ==="
  echo "AccessDenied: User: arn:aws:sts::<account>:assumed-role/<cluster>-lbc-irsa/... " \
       "is not authorized to perform: elasticloadbalancing:CreateLoadBalancer " \
       "on resource: arn:aws:elasticloadbalancing:<region>:<account>:loadbalancer/*"
  echo "Avec cette erreur, le Service web reste en <pending> : EXTERNAL-IP n'apparaît " \
       "jamais, car le contrôleur n'a pas pu créer le NLB via l'API ELBv2."
} > /var/work/tests/artifacts/6/reconcile.txt

cat /var/work/tests/artifacts/6/reconcile.txt
```

## Vérification rapide

```bash
check_result
```
