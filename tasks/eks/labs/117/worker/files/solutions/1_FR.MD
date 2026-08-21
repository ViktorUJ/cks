[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 117 - solution de référence (NAT par AZ vs. NAT unique, VPC endpoints, cross-AZ)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà
configuré pour le cluster (le kubeconfig a été généré via `aws eks update-kubeconfig` au
démarrage de la machine).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
export VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
kubectl create namespace eks-117
```

## Tâche 1. Combien de NAT Gateways, et dans quelles zones

Le réseau du labo est monté de sorte qu'un NAT Gateway n'existe que dans deux des trois
AZ privées. Cherchons tous les NAT Gateways de cette VPC :

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[].[NatGatewayId,SubnetId,State]' --output table
```

Pour chaque NAT, déterminons l'AZ de son subnet :

```bash
NAT1=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[0].NatGatewayId' --output text)
NAT1_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT1" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT1_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT1_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

NAT2=$(aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[1].NatGatewayId' --output text)
NAT2_SUBNET=$(aws ec2 describe-nat-gateways --nat-gateway-ids "$NAT2" \
  --query 'NatGateways[0].SubnetId' --output text)
NAT2_AZ=$(aws ec2 describe-subnets --subnet-ids "$NAT2_SUBNET" \
  --query 'Subnets[0].AvailabilityZone' --output text)

echo "nat1=$NAT1 az=$NAT1_AZ / nat2=$NAT2 az=$NAT2_AZ"
```

Les deux AZ qui ont un NAT sont `eu-central-1a` et `eu-central-1b`. Le subnet privé de
`eu-central-1c` existe (il porte le tag `karpenter.sh/discovery`, pour que Karpenter
puisse y placer des nodes), mais il n'y a pas de NAT Gateway dans cette zone :

```bash
mkdir -p /var/work/tests/artifacts/1
cat > /var/work/tests/artifacts/1/natdiscovery.txt <<EOF
nat_count=2
nat_1_id=$NAT1
nat_1_az=$NAT1_AZ
nat_2_id=$NAT2
nat_2_az=$NAT2_AZ
no_nat_az=eu-central-1c
EOF
cat /var/work/tests/artifacts/1/natdiscovery.txt
```

## Tâche 2. Reproduire le piège cross-AZ

Cherchons la table de routage du subnet `private-subnet-3` (elle est dans
`eu-central-1c`, sans NAT) :

```bash
RTB_C=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-3" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "route table AZ 1c = $RTB_C"
```

Pointons la route `0.0.0.0/0` de cette table de routage vers le NAT Gateway d'une des AZ
voisines - on prend `NAT1` (dans `eu-central-1a`), et c'est exactement l'étape qui crée
le chemin cross-AZ :

```bash
aws ec2 create-route --route-table-id "$RTB_C" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT1"

aws ec2 describe-route-tables --route-table-ids "$RTB_C" \
  --query 'RouteTables[0].Routes'
```

Créons une charge qui demande spécifiquement la zone `eu-central-1c`, pour que Karpenter
lève un node là-bas. L'image est `curlimages/curl:latest` avec une `command` endormie :
depuis ce pod on vérifiera plus tard l'egress via `kubectl exec`, donc le conteneur a
besoin d'un shell et de `curl` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: crossaz
  namespace: eks-117
spec:
  replicas: 1
  selector:
    matchLabels:
      app: crossaz
  template:
    metadata:
      labels:
        app: crossaz
    spec:
      nodeSelector:
        topology.kubernetes.io/zone: eu-central-1c
      containers:
      - name: app
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/crossaz -n eks-117
```

Vérifions le node et sa zone, puis l'egress depuis l'intérieur du pod :

```bash
POD=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].metadata.name}')
NODE=$(kubectl get po -n eks-117 -l app=crossaz -o jsonpath='{.items[0].spec.nodeName}')
NODE_ZONE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}')
echo "node=$NODE zone=$NODE_ZONE"

HTTP_CODE=$(kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}' https://checkip.amazonaws.com)
echo "egress_http_code=$HTTP_CODE"
```

L'egress fonctionne (`200`), mais c'est exactement le piège du chapitre 31 : le pod vit
dans `eu-central-1c`, tandis que ses paquets traversent d'abord la frontière d'AZ vers le
NAT dans `eu-central-1a`, et ne partent qu'ensuite. Ce saut est facturé comme trafic
cross-AZ séparément des frais de traitement propres au NAT - ce qui signifie qu'on paie
deux fois pour le même octet. Le bon schéma est un NAT Gateway dans chaque AZ qui a des
nodes (comme c'est déjà fait pour `eu-central-1a` et `eu-central-1b` dans ce labo), pour
que le trafic d'un node ne quitte jamais sa propre zone avant d'atteindre un NAT.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/crossaz.txt <<EOF
subnet_c_route_table_id=$RTB_C
nat_gateway_id_used=$NAT1
nat_gateway_az_used=$NAT1_AZ
pod_node=$NODE
pod_node_zone=$NODE_ZONE
egress_http_code=$HTTP_CODE

La route 0.0.0.0/0 du subnet eu-central-1c pointe vers un NAT Gateway dans une zone
différente ($NAT1_AZ), donc tout le trafic sortant depuis un node de eu-central-1c passe
en cross-AZ : d'abord un saut inter-AZ vers le NAT, puis un traitement sur le NAT
lui-même. Cela est facturé deux fois - une fois pour le trafic inter-AZ (cross-AZ) et une
fois pour les gigaoctets traités par le NAT. Le bon schéma est un NAT Gateway dans chaque
AZ qui a des nodes, pour que le trafic ne traverse jamais de frontière de zone.
EOF
cat /var/work/tests/artifacts/2/crossaz.txt
```

## Tâche 3. Gateway VPC endpoint pour S3 - une route gratuite

Cherchons les tables de routage des trois subnets privés :

```bash
RTB_A=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-1" \
  --query 'RouteTables[0].RouteTableId' --output text)
RTB_B=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-2" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "rtb_a=$RTB_A rtb_b=$RTB_B rtb_c=$RTB_C"
```

Créons un gateway endpoint pour S3 et attachons-le tout de suite aux trois tables de
routage :

```bash
S3_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Gateway --service-name com.amazonaws.eu-central-1.s3 \
  --route-table-ids "$RTB_A" "$RTB_B" "$RTB_C" \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "attente que l'endpoint S3 devienne available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
  --query 'VpcEndpoints[0].{State:State,RouteTableIds:RouteTableIds}'
```

Un gateway endpoint pour S3 ne crée pas d'ENI et n'est facturé ni à l'heure ni pour les
gigaoctets traités - c'est juste une entrée de table de routage, ce qui en fait la
première étape d'optimisation, et la plus rentable :

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/s3endpoint.txt <<EOF
vpc_endpoint_id=$S3_EP
state=available
route_tables=$RTB_A,$RTB_B,$RTB_C

Un gateway endpoint pour S3 n'est qu'une entrée de table de routage, et il est gratuit
(free of charge) : il n'y a ni frais horaire ni frais par donnée traitée, contrairement à un
interface endpoint.
EOF
cat /var/work/tests/artifacts/3/s3endpoint.txt
```

## Tâche 4. Interface VPC endpoint pour un service à fort trafic

Choisissons `sts` - chaque pod utilisant IRSA ou EKS Pod Identity échange son token
contre des identifiants temporaires via STS à chaque démarrage et à chaque
renouvellement d'identifiants, et sans endpoint cet échange passe par NAT à chaque
requête de ce type. (L'alternative est `ecr.api` : autorisation du registre d'images à
chaque pull; choisir l'un ou l'autre est accepté par le test.)

Prenons le security group par défaut et autorisons immédiatement l'entrée HTTPS depuis
le CIDR de la VPC. Sans cette règle l'endpoint serait créé mais inaccessible : la règle
d'entrée du security group par défaut n'autorise que le trafic venant des membres du
même groupe, alors que les nodes et pods de Karpenter vivent dans d'autres groupes.

```bash
SG=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC" \
  "Name=group-name,Values=default" --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id "$SG" \
  --protocol tcp --port 443 --cidr 10.10.0.0/16

STS_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Interface --service-name com.amazonaws.eu-central-1.sts \
  --subnet-ids "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-1" \
    --query 'Subnets[0].SubnetId' --output text)" \
    "$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=private-subnet-2" \
    --query 'Subnets[0].SubnetId' --output text)" \
  --security-group-ids "$SG" --private-dns-enabled \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "attente que l'endpoint sts devienne available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
  --query 'VpcEndpoints[0].{State:State,PrivateDnsEnabled:PrivateDnsEnabled}'
```

Vérifions que l'endpoint répond réellement depuis l'intérieur du cluster -
`private_dns_enabled=true` signifie que le nom `sts.eu-central-1.amazonaws.com` résout
maintenant vers les adresses privées de l'ENI de l'endpoint dans toute la VPC, et si la
règle `443` n'avait pas été ajoutée, STS aurait cessé de fonctionner pour tous les pods
à la fois :

```bash
kubectl exec -n eks-117 "$POD" -- nslookup sts.eu-central-1.amazonaws.com
kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 8 \
  https://sts.eu-central-1.amazonaws.com
```

Le nom résout vers des adresses de `10.10.15.0/24` et `10.10.16.0/24` (ce sont les ENI de
l'endpoint), et `curl` renvoie le code `302` - une vraie réponse STS via PrivateLink. Le
code `000` et un timeout auraient signifié que le security group de l'endpoint ne
laissait pas passer le trafic venant des pods.

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/interfaceendpoint.txt <<EOF
service_chosen=sts
vpc_endpoint_id=$STS_EP
state=available
private_dns_enabled=true

Choix de sts : IRSA et EKS Pod Identity échangent un token contre des clés temporaires
via STS à chaque démarrage de pod et à chaque renouvellement d'identifiants, c'est une
requête fréquente, et sans endpoint elle passe par NAT. Un interface endpoint retire ce
trafic de NAT, au prix d'un frais horaire par ENI dans chaque AZ plus un frais pour les
gigaoctets traités.
EOF
cat /var/work/tests/artifacts/4/interfaceendpoint.txt
```

## Tâche 5. Métriques NAT : combien d'octets sont passés par chaque gateway

Récupérons la somme de `BytesOutToDestination` sur les dernières heures pour chaque NAT
(namespace `AWS/NATGateway`) :

```bash
START=$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%S)
END=$(date -u +%Y-%m-%dT%H:%M:%S)

NAT_A_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT1" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_A_SUM" == "None" ]] && NAT_A_SUM=0

NAT_B_SUM=$(aws cloudwatch get-metric-statistics --namespace AWS/NATGateway \
  --metric-name BytesOutToDestination --statistics Sum --period 3600 \
  --dimensions Name=NatGatewayId,Value="$NAT2" \
  --start-time "$START" --end-time "$END" \
  --query 'sum(Datapoints[].Sum)' --output text)
[[ "$NAT_B_SUM" == "None" ]] && NAT_B_SUM=0

TOTAL=$(python3 -c "print(int(${NAT_A_SUM%.*}) + int(${NAT_B_SUM%.*}))")
echo "nat_a=$NAT1 sum=$NAT_A_SUM / nat_b=$NAT2 sum=$NAT_B_SUM / total=$TOTAL"
```

`NAT1` est le même NAT Gateway vers lequel la tâche 2 a pointé la route du subnet
`eu-central-1c`. Il a pris en charge à la fois le trafic normal de sa propre zone
`eu-central-1a` et le trafic cross-AZ venant du node `crossaz`, on s'attend donc à ce
qu'il affiche un volume de `BytesOutToDestination` plus grand sur la même fenêtre que
`NAT2`, qui ne sert que sa propre AZ :

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/natmetrics.txt <<EOF
nat_a_id=$NAT1
nat_a_bytes_out_sum=${NAT_A_SUM%.*}
nat_b_id=$NAT2
nat_b_bytes_out_sum=${NAT_B_SUM%.*}
total_bytes_out_sum=$TOTAL

Métrique : AWS/NATGateway BytesOutToDestination, somme sur les points de données de la
période. Le NAT $NAT1 a pris en charge le trafic cross-AZ venant du node crossaz dans
eu-central-1c (tâche 2) en plus du trafic normal de sa propre zone, on s'attend donc à ce
qu'il affiche un volume de BytesOutToDestination plus grand que $NAT2, qui ne sert que
sa propre AZ.
EOF
cat /var/work/tests/artifacts/5/natmetrics.txt
```

Si la charge de test a réussi à générer un trafic notable (par exemple, des requêtes
`curl` répétées depuis le pod `crossaz`), la différence des sommes est déjà visible sur
la première fenêtre de métrique; si la charge était ponctuelle, la différence peut être
faible - ce qui compte, c'est le fait que le NAT ayant pris en charge le node cross-AZ
affiche un volume non inférieur à l'autre.

## Vérification rapide

```bash
check_result
```
