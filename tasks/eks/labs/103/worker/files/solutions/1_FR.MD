[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 103 - solution de référence (plan d'adressage : ENI, prefix delegation, secondary CIDR)

Toutes les commandes s'exécutent sur la machine de travail (worker) via SSH. kubectl est
déjà configuré pour le cluster (le kubeconfig est assemblé via `aws eks
update-kubeconfig` au démarrage de la machine).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
kubectl create namespace eks-103
```

## Tâche 1. Calcul de max-pods par formule et comparaison avec la valeur réelle

Nous créons la charge de base et attendons que Karpenter lève pour elle un nœud EC2 dans
le mode normal (par adresse) de VPC CNI - l'addon n'est pas encore passé en prefix
delegation :

```bash
kubectl create deployment baseline --image=viktoruj/ping_pong:latest --replicas=2 -n eks-103
kubectl rollout status deployment/baseline -n eks-103

NODE=$(kubectl get po -n eks-103 -l app=baseline -o jsonpath='{.items[0].spec.nodeName}')
TYPE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
echo "node=$NODE type=$TYPE"
```

Nous récupérons le nombre d'ENI, les IP par ENI et les vCPU pour ce type d'instance :

```bash
ENI=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkInterfaces' --output text)
IPS=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.Ipv4AddressesPerInterface' --output text)
VCPU=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' --output text)
echo "eni=$ENI ips_per_eni=$IPS vcpu=$VCPU"
```

Nous calculons avec la formule `max-pods = ENI * (IP par ENI - 1) + 2` et appliquons le
plafond du managed node group (`110` si `vCPU < 30`, sinon `250`) :

```bash
FORMULA=$((ENI * (IPS - 1) + 2))
if [ "$VCPU" -lt 30 ]; then CAP=110; else CAP=250; fi
if [ "$FORMULA" -lt "$CAP" ]; then EXPECTED=$FORMULA; else EXPECTED=$CAP; fi
echo "formula=$FORMULA cap=$CAP expected_max_pods=$EXPECTED"

ACTUAL=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.pods}')
echo "actual_allocatable_pods=$ACTUAL"
```

Exemple pour `m5.large` : `ENI=3`, `IP par ENI=10` donnent `formula = 3*(10-1)+2 = 29`, le
plafond `110` n'intervient pas (`29 < 110`), donc `expected_max_pods = 29` - et c'est
exactement ce que `kubectl get node` doit afficher.

Nous enregistrons le calcul et la valeur réelle dans l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/maxpods.txt <<EOF
node=$NODE
instance_type=$TYPE
eni=$ENI
ips_per_eni=$IPS
vcpu=$VCPU
formula=$FORMULA
cap=$CAP
expected_max_pods=$EXPECTED
actual_allocatable_pods=$ACTUAL
EOF
cat /var/work/tests/artifacts/1/maxpods.txt
```

Si `expected_max_pods` et `actual_allocatable_pods` ne correspondent pas - kubelet ne
connaît max-pods qu'au démarrage du nœud, la comparaison doit donc être faite sur un nœud
déjà complètement Ready.

## Tâche 2. Prefix delegation : nouveau nœud contre ancien nœud

Nous figeons l'état de l'ancien nœud (mode par adresse) avant d'activer prefix
delegation :

```bash
OLD_NODE="$NODE"
OLD_PODS=$(kubectl get node "$OLD_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "old_node=$OLD_NODE old_node_allocatable_pods=$OLD_PODS"
```

Nous activons prefix delegation sur l'addon géré `vpc-cni` (ne fonctionne que sur les
instances basées sur Nitro, d'où l'importance que le NodePool utilise ces types) :

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --configuration-values '{"env":{"ENABLE_PREFIX_DELEGATION":"true","WARM_PREFIX_TARGET":"1"}}' \
  --resolve-conflicts PRESERVE

aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --query 'addon.configurationValues'
```

Prefix delegation ne concerne que les nouveaux nœuds : l'ancien nœud `baseline` a déjà
reçu sa limite `allocatable.pods` de kubelet au démarrage et ne la recalculera pas avant
d'être recréé. Nous provoquons la création d'un nouveau nœud avec une charge qui ne tient
pas sur l'ancien :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scale
  namespace: eks-103
spec:
  replicas: 6
  selector:
    matchLabels:
      app: scale
  template:
    metadata:
      labels:
        app: scale
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "1"
            memory: "128Mi"
EOF

kubectl rollout status deployment/scale -n eks-103
```

Nous identifions le nouveau nœud et comparons les limites :

```bash
NEW_NODE=$(kubectl get po -n eks-103 -l app=scale -o jsonpath='{.items[*].spec.nodeName}' \
  | tr ' ' '\n' | grep -v "^${OLD_NODE}$" | head -n1)
NEW_TYPE=$(kubectl get node "$NEW_NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
NEW_PODS=$(kubectl get node "$NEW_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "new_node=$NEW_NODE new_node_instance_type=$NEW_TYPE new_node_allocatable_pods=$NEW_PODS"
```

Exemple pour `m5.large` en mode préfixes : la limite passe de `29` à `434` (plafonnée par
le plafond du managed node group `110`, donc le plafond réel est `110`, mais cela reste
bien plus que le `29` du mode par adresse).

Nous enregistrons la comparaison et l'explication dans l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/prefixdelegation.txt <<EOF
old_node=$OLD_NODE
old_node_allocatable_pods=$OLD_PODS
new_node=$NEW_NODE
new_node_instance_type=$NEW_TYPE
new_node_allocatable_pods=$NEW_PODS

old_node_allocatable_pods n'a pas changé parce que kubelet calcule max-pods une seule
fois, au démarrage du nœud, et prefix delegation ne concerne que les nouveaux nœuds, pas
ceux déjà en marche. new_node a été créé après l'activation de prefix delegation, donc
ses ENI portent des préfixes /28 (16 adresses chacun) plutôt que des IP isolées, et la
limite de pods est nettement plus élevée.
EOF
cat /var/work/tests/artifacts/2/prefixdelegation.txt
```

## Tâche 3. Planification de la taille du sous-réseau pour la croissance

Nous calculons le besoin final : `850` pods, marge de `20%` pour le warm pool, puis encore
`15%` pour le rolling update (les marges se multiplient de façon séquentielle) :

```bash
python3 - <<'EOF'
base = 850
after_warm = base * 1.20
after_roll = after_warm * 1.15
print(f"base={base} after_warm_pool={after_warm:.0f} after_rolling_update={after_roll:.0f}")
EOF
```

Résultat : `850 * 1.20 = 1020`, `1020 * 1.15 = 1173` - le besoin final est d'environ
`1173` adresses. Nous comparons avec le tableau des adresses disponibles par préfixe de
sous-réseau (AWS réserve `5` adresses par sous-réseau) :

- `/24` - total `256`, disponibles `251` - moins que `1173`, ne convient pas;
- `/22` - total `1024`, disponibles `1019` - également moins que `1173`, ne convient pas;
- `/20` - total `4096`, disponibles `4091` - largement suffisant.

`4091 / 1173 ≈ 3.5` fois de marge, ce qui couvre à la fois le calcul actuel et la
croissance future, c'est pourquoi nous choisissons `/20`.

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/cidrplan.txt <<'EOF'
Besoin : 850 pods * 1.20 (marge pour warm pool) * 1.15 (marge pour rolling update)
= 1173 adresses (besoin final en adresses).

/24 (total 256, disponibles 251) - ne convient pas, disponible est inférieur au besoin.
/22 (total 1024, disponibles 1019) - ne convient pas, disponible est inférieur au besoin (1173).
/20 (total 4096, disponibles 4091) - convient : 4091 / 1173 ~= 3.5 fois de marge.

Choix : /20. Le warm pool de Karpenter et un rolling update simultané occupent
brièvement des adresses supplémentaires, le sous-réseau doit donc être nettement plus
grand que le pic ponctuel, pas juste au ras de 1173 adresses.
EOF
cat /var/work/tests/artifacts/3/cidrplan.txt
```

## Tâche 4. Secondary CIDR : nous étendons le plan d'adressage du VPC

Nous récupérons le `vpc-id` du cluster et rattachons un secondary CIDR issu du shared
address space RFC 6598 (`100.64.0.0/16` ne chevauche pas le CIDR primaire
`10.10.0.0/16` de ce VPC) :

```bash
VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 associate-vpc-cidr-block --vpc-id "$VPC" --cidr-block 100.64.0.0/16
```

Nous attendons l'état `associated` (juste après l'appel le bloc peut être en
`associating`) :

```bash
until aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query "Vpcs[].CidrBlockAssociationSet[?CidrBlock=='100.64.0.0/16'].CidrBlockState.State" \
    --output text | grep -q associated; do
  echo "waiting for secondary CIDR to become associated..."
  sleep 5
done

aws ec2 describe-vpcs --vpc-ids "$VPC" \
  --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}'
```

Nous créons un sous-réseau dans le nouveau bloc :

```bash
SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 100.64.1.0/24 \
  --availability-zone eu-central-1a --query 'Subnet.SubnetId' --output text)
echo "subnet=$SUBNET"
```

Nous enregistrons le résultat dans l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "secondary_cidr=100.64.0.0/16"
  aws ec2 describe-vpcs --vpc-ids "$VPC" \
    --query 'Vpcs[].CidrBlockAssociationSet[].{CIDR:CidrBlock,State:CidrBlockState.State}' \
    --output table
  echo "subnet_id=$SUBNET"
} > /var/work/tests/artifacts/4/secondary_cidr.txt
cat /var/work/tests/artifacts/4/secondary_cidr.txt
```

Si nous avions essayé `172.16.0.0/12` ou `192.168.0.0/16` au lieu de `100.64.0.0/16` -
AWS ne permettrait pas de les ajouter à un VPC dont le CIDR primaire est déjà dans la
plage `10.0.0.0/8` (chevauchement entre plages privées RFC 1918), c'est pourquoi on
utilise généralement RFC 6598.

## Tâche 5. Diagnostic d'une pénurie d'adresses (sans panne réelle)

Nous ne touchons pas à l'infrastructure du lab : nous ne réduisons pas les sous-réseaux et
n'épuisons pas les adresses artificiellement. Nous regardons l'état actuel des
sous-réseaux du cluster - ce sont les mêmes commandes utilisées pour diagnostiquer une
pénurie d'adresses sur un cluster réel :

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

Nous enregistrons l'explication du diagnostic de pénurie d'adresses dans l'artefact :

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnostics.txt <<'EOF'
Comment diagnostiquer une pénurie d'adresses IP sur un cluster réel :

1. Symptôme sur le pod : kubectl describe pod affichera dans Events l'événement
   FailedCreatePodSandBox venant de aws-cni - c'est le premier signal que VPC CNI n'a
   pas pu attribuer d'adresse.

2. Pénurie générale d'adresses dans un sous-réseau : aws ec2 describe-subnets --query
   'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' - si
   AvailableIpAddressCount de cette AZ est 0, c'est un diagnostic direct
   d'épuisement des adresses dans ce sous-réseau et cette AZ.

3. Fragmentation plutôt que réelle pénurie : si prefix delegation est activé mais qu'il
   n'y a pas de bloc contigu /28 dans le sous-réseau (les adresses sont dispersées en IP
   individuelles occupées), les logs ipamd/aws-node afficheront une erreur
   InsufficientCidrBlocks, même quand l'AvailableIpAddressCount du sous-réseau paraît
   élevé. Ce sont des causes différentes du même symptôme externe (un pod ne peut pas
   obtenir d'adresse), et elles se traitent différemment : la pénurie d'adresses se
   traite en agrandissant le CIDR ou en ajoutant un secondary CIDR (tâche 4), la
   fragmentation se traite en libérant de la place pour un bloc contigu ou en créant un
   nouveau sous-réseau.
EOF
cat /var/work/tests/artifacts/5/diagnostics.txt
```

## Vérification rapide

```bash
check_result
```
