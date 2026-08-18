[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 101 - solution de référence (cluster en tant que code : accès, compute, réseau, AMI)

Toutes les commandes s'exécutent sur la machine de travail (worker) via SSH. kubectl est
déjà configuré pour le cluster (le kubeconfig est assemblé via `aws eks update-kubeconfig`
au démarrage de la machine).

## Tâche 1. Namespace `eks-101`

```bash
kubectl create namespace eks-101
```

## Tâche 2. Deployment `web` (viktoruj/ping_pong, 3 réplicas) sur des nœuds EC2

Les pods système (kube-system, karpenter) vont sur Fargate, tandis que n'importe quel pod
dans un namespace normal est planifié sur un nœud EC2 que Karpenter monte. Le Deployment
dans `eks-101` atterrit donc automatiquement sur EC2 :

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3 -n eks-101
kubectl rollout status deployment/web -n eks-101
```

Vérification que les pods ne sont pas sur Fargate (le nom du nœud commence par `ip-`, pas
par `fargate-`) :

```bash
kubectl get po -n eks-101 -l app=web -o wide
```

Pourquoi : Fargate ne fait tourner un pod que si le namespace du pod correspond à un profile
Fargate. Dans ce laboratoire, le profile est configuré pour `kube-system` et `karpenter`, et
il n'y en a pas pour `eks-101`, donc c'est Karpenter (EC2) qui prend en charge la workload
`eks-101`. Vous consignerez cette explication à la tâche 7.

## Tâche 3. Artefact : séparation des nœuds système et des nœuds de travail

On enregistre la liste des nœuds en indiquant lesquels sont Fargate et lesquels sont EC2 :

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -o wide > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt
```

Le fichier doit contenir à la fois des nœuds `fargate-...` (pods système) et des nœuds
`ip-...` (nœuds de travail Karpenter). C'est exactement la séparation de compute du
chapitre 9.

## Tâche 4. Artefact : IP d'un pod dans le CIDR du VPC

VPC CNI attribue aux pods des adresses routables depuis le sous-réseau du nœud
(`10.10.15.0/24` ou `10.10.16.0/24`), donc depuis le VPC `10.10.0.0/16` :

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].status.podIP}' \
  > /var/work/tests/artifacts/4/podip.txt
echo >> /var/work/tests/artifacts/4/podip.txt
cat /var/work/tests/artifacts/4/podip.txt
```

Pour mieux comprendre VPC CNI, comparez l'adresse du pod aux CIDR des sous-réseaux privés
(le pod a reçu une IP du sous-réseau de son propre nœud) :

```bash
VPC=$(aws eks describe-cluster --name "$(kubectl config current-context | sed 's|.*/||')" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text 2>/dev/null)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[CidrBlock,AvailabilityZone]' --output table
```

## Tâche 5. Artefact : AMI du nœud de travail (AL2023)

On regarde l'image OS de n'importe quel nœud de travail (EC2). Le NodePool par défaut est
construit sur `al2023@latest`, donc c'est Amazon Linux 2023 :

```bash
mkdir -p /var/work/tests/artifacts/5
NODE=$(kubectl get po -n eks-101 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
kubectl get node "$NODE" -o jsonpath='{.status.nodeInfo.osImage}' \
  > /var/work/tests/artifacts/5/ami.txt
echo >> /var/work/tests/artifacts/5/ami.txt
cat /var/work/tests/artifacts/5/ami.txt
```

## Tâche 6. Deployment `batch` (6 réplicas avec requête CPU) - montée en échelle via Karpenter

Une workload avec des requests explicites force Karpenter à ajouter des ressources de
compute. On crée le deployment avec une requête CPU et on attend que toutes les réplicas
soient prêtes :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch
  namespace: eks-101
spec:
  replicas: 6
  selector:
    matchLabels:
      app: batch
  template:
    metadata:
      labels:
        app: batch
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/batch -n eks-101
```

Pour observer comment Karpenter monte des nœuds :

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type=default -o wide
kubectl logs -n karpenter -l app.kubernetes.io/instance=karpenter | tail -n 20
```

## Tâche 7. Frontière de responsabilité : symptôme et explication

On demande délibérément Fargate là où il n'existe pas. Le pod doit rester bloqué en
`Pending` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-probe
  namespace: eks-101
spec:
  nodeSelector:
    eks.amazonaws.com/compute-type: fargate
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get po fg-probe -n eks-101 -o wide
kubectl describe po fg-probe -n eks-101 | sed -n '/Events/,$p'
# événements de tout le namespace triés par horodatage - une compétence de diagnostic SRE pour les échecs de planification
kubectl get events -n eks-101 --sort-by='.metadata.creationTimestamp'
```

Le pod reste `Pending` : il n'y a pas de profile Fargate pour `eks-101`, donc EKS ne planifie
pas le pod sur Fargate, et Karpenter ne crée pas non plus de nœud EC2, car ses nœuds ne
portent pas le label `eks.amazonaws.com/compute-type: fargate`. Personne ne peut satisfaire
cette exigence.

On enregistre l'explication en tant qu'artefact :

```bash
mkdir -p /var/work/tests/artifacts/7
cat > /var/work/tests/artifacts/7/whyfargate.txt <<'EOF'
Les pods web et batch sont allés sur des nœuds EC2 Karpenter, pas sur Fargate : Fargate ne
fait tourner un pod que si le namespace du pod correspond à un profile Fargate. Le cluster a
un profile pour kube-system et karpenter, mais aucun pour eks-101.

fg-probe est resté bloqué en Pending car il demande explicitement Fargate (nodeSelector
eks.amazonaws.com/compute-type: fargate), mais il n'y a pas de profile pour eks-101, et les
nœuds EC2 de Karpenter ne portent pas ce label. Ni Fargate ni Karpenter ne peuvent satisfaire
cette exigence.
EOF
cat /var/work/tests/artifacts/7/whyfargate.txt
```

La frontière de responsabilité devient claire : quels namespaces vont sur Fargate dépend de
vous (via les profiles Fargate, chapitre 9), pas d'une décision d'EKS "tout seul".

## Vérification rapide

```bash
check_result
```
