[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 117 - solución de referencia (NAT por AZ frente a un único NAT, VPC endpoints, cross-AZ)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el cluster (el kubeconfig se generó con `aws eks update-kubeconfig` al arrancar la
máquina).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
export VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)
kubectl create namespace eks-117
```

## Tarea 1. Cuántos NAT Gateways hay, y en qué zonas

La red del lab está configurada de forma que solo existe un NAT Gateway en dos de las
tres AZ privadas. Vamos a encontrar todos los NAT Gateways de este VPC:

```bash
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[].[NatGatewayId,SubnetId,State]' --output table
```

Para cada NAT, vamos a determinar la AZ de su subred:

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

Ambas AZ que tienen NAT son `eu-central-1a` y `eu-central-1b`. La subred privada en
`eu-central-1c` existe (lleva la etiqueta `karpenter.sh/discovery`, así que Karpenter
puede colocar nodes en ella), pero no hay ningún NAT Gateway en esa zona:

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

## Tarea 2. Reproduciendo la trampa cross-AZ

Vamos a encontrar la tabla de rutas de la subred `private-subnet-3` (está en
`eu-central-1c`, sin NAT):

```bash
RTB_C=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-3" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "route table AZ 1c = $RTB_C"
```

Vamos a apuntar la ruta `0.0.0.0/0` de esta tabla de rutas hacia el NAT Gateway de una de
las AZ vecinas - tomamos `NAT1` (en `eu-central-1a`), y este es exactamente el paso que
crea la ruta cross-AZ:

```bash
aws ec2 create-route --route-table-id "$RTB_C" \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT1"

aws ec2 describe-route-tables --route-table-ids "$RTB_C" \
  --query 'RouteTables[0].Routes'
```

Vamos a crear una carga de trabajo que solicita específicamente la zona
`eu-central-1c`, para que Karpenter levante un node ahí. La imagen es
`curlimages/curl:latest` con un `command` que la deja dormida: desde este pod más
adelante comprobaremos el egress vía `kubectl exec`, así que el contenedor necesita una
shell y `curl`:

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

Vamos a comprobar el node y su zona, y luego el egress desde dentro del pod:

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

El egress funciona (`200`), pero esto es exactamente la trampa del capítulo 31: el pod
vive en `eu-central-1c`, mientras que sus paquetes primero cruzan el límite de la AZ
hacia el NAT en `eu-central-1a`, y solo entonces salen. Ese salto se factura como tráfico
cross-AZ por separado de la propia cuota de procesamiento del NAT - es decir, pagas dos
veces por el mismo byte. El patrón correcto es un NAT Gateway en cada AZ que tenga nodes
(como ya se hace para `eu-central-1a` y `eu-central-1b` en este lab), de modo que el
tráfico de un node nunca salga de su propia zona antes de llegar a un NAT.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/crossaz.txt <<EOF
subnet_c_route_table_id=$RTB_C
nat_gateway_id_used=$NAT1
nat_gateway_az_used=$NAT1_AZ
pod_node=$NODE
pod_node_zone=$NODE_ZONE
egress_http_code=$HTTP_CODE

La ruta 0.0.0.0/0 de la subred eu-central-1c apunta a un NAT Gateway en una zona
distinta ($NAT1_AZ), así que todo el tráfico de salida de un node en eu-central-1c va
cross-AZ: primero un salto inter-AZ hacia el NAT, luego el procesamiento en el propio
NAT. Esto se factura dos veces - una por el tráfico inter-AZ (cross-AZ) y otra por los
gigabytes procesados por el NAT. El patrón correcto es un NAT Gateway en cada AZ que
tenga nodes, para que el tráfico nunca cruce ningún límite de zona.
EOF
cat /var/work/tests/artifacts/2/crossaz.txt
```

## Tarea 3. Gateway VPC endpoint para S3 - una ruta gratuita

Vamos a encontrar las tablas de rutas de las tres subredes privadas:

```bash
RTB_A=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-1" \
  --query 'RouteTables[0].RouteTableId' --output text)
RTB_B=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=private-subnet-2" \
  --query 'RouteTables[0].RouteTableId' --output text)
echo "rtb_a=$RTB_A rtb_b=$RTB_B rtb_c=$RTB_C"
```

Vamos a crear un gateway endpoint para S3 y a adjuntarlo de inmediato a las tres tablas
de rutas:

```bash
S3_EP=$(aws ec2 create-vpc-endpoint --vpc-id "$VPC" \
  --vpc-endpoint-type Gateway --service-name com.amazonaws.eu-central-1.s3 \
  --route-table-ids "$RTB_A" "$RTB_B" "$RTB_C" \
  --query 'VpcEndpoint.VpcEndpointId' --output text)

until aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
    --query 'VpcEndpoints[0].State' --output text | grep -q available; do
  echo "waiting for the S3 endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$S3_EP" \
  --query 'VpcEndpoints[0].{State:State,RouteTableIds:RouteTableIds}'
```

Un gateway endpoint para S3 no crea ningún ENI y no se factura ni por hora ni por
gigabytes procesados - es solo una entrada en la tabla de rutas, lo que lo convierte en
el primer paso de optimización y el más rentable:

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/s3endpoint.txt <<EOF
vpc_endpoint_id=$S3_EP
state=available
route_tables=$RTB_A,$RTB_B,$RTB_C

Un gateway endpoint para S3 es solo una entrada en la tabla de rutas, y es gratis
(бесплат): no hay ni cuota por hora ni cuota por dato procesado, a diferencia de un
interface endpoint.
EOF
cat /var/work/tests/artifacts/3/s3endpoint.txt
```

## Tarea 4. Interface VPC endpoint para un servicio de alto tráfico

Vamos a elegir `sts` - cada pod que usa IRSA o EKS Pod Identity intercambia su token por
credenciales temporales vía STS en cada arranque y en cada renovación de credenciales, y
sin un endpoint ese intercambio pasa por el NAT en cada una de esas peticiones. (La
alternativa es `ecr.api`: autorización del registro de imágenes en cada pull; elegir
cualquiera de los dos es aceptado por el test.)

Vamos a tomar el security group por defecto y a permitir de inmediato el tráfico
entrante HTTPS desde el CIDR del VPC en él. Sin esta regla el endpoint se crearía pero
sería inalcanzable: la regla de entrada del security group por defecto solo permite
tráfico de miembros del mismo grupo, mientras que los nodes y los pods de Karpenter viven
en otros grupos.

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
  echo "waiting for the sts endpoint to become available..."
  sleep 5
done

aws ec2 describe-vpc-endpoints --vpc-endpoint-ids "$STS_EP" \
  --query 'VpcEndpoints[0].{State:State,PrivateDnsEnabled:PrivateDnsEnabled}'
```

Vamos a comprobar que el endpoint responde de verdad desde dentro del cluster -
`private_dns_enabled=true` significa que el nombre `sts.eu-central-1.amazonaws.com` ahora
se resuelve hacia las direcciones privadas del ENI del endpoint en todo el VPC, y si no
se hubiera añadido la regla `443`, STS dejaría de funcionar para todos los pods a la vez:

```bash
kubectl exec -n eks-117 "$POD" -- nslookup sts.eu-central-1.amazonaws.com
kubectl exec -n eks-117 "$POD" -- \
  curl -s -o /dev/null -w '%{http_code}\n' --connect-timeout 8 \
  https://sts.eu-central-1.amazonaws.com
```

El nombre se resuelve hacia direcciones de `10.10.15.0/24` y `10.10.16.0/24` (son los
ENIs del endpoint), y `curl` devuelve el código `302` - una respuesta real de STS a través
de PrivateLink. El código `000` y un timeout habrían significado que el security group del
endpoint no dejaba pasar el tráfico desde los pods.

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/interfaceendpoint.txt <<EOF
service_chosen=sts
vpc_endpoint_id=$STS_EP
state=available
private_dns_enabled=true

Se elige sts: IRSA y EKS Pod Identity intercambian un token por claves temporales vía
STS en cada arranque de pod y en cada renovación de credenciales, es una petición
frecuente, y sin un endpoint pasa por el NAT. Un interface endpoint saca este tráfico
del NAT, a costa de una cuota por hora por ENI en cada AZ más una cuota por gigabytes
procesados.
EOF
cat /var/work/tests/artifacts/4/interfaceendpoint.txt
```

## Tarea 5. Métricas del NAT: cuántos bytes pasaron por cada gateway

Vamos a obtener la suma de `BytesOutToDestination` de las últimas horas para cada NAT
(namespace `AWS/NATGateway`):

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

`NAT1` es el mismo NAT Gateway al que la tarea 2 apuntó la ruta de la subred de
`eu-central-1c`. Asumió tanto el tráfico habitual de su propia zona `eu-central-1a` como
el tráfico cross-AZ del node `crossaz`, así que se espera que muestre un volumen mayor de
`BytesOutToDestination` en la misma ventana que `NAT2`, que solo sirve a su propia AZ:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/natmetrics.txt <<EOF
nat_a_id=$NAT1
nat_a_bytes_out_sum=${NAT_A_SUM%.*}
nat_b_id=$NAT2
nat_b_bytes_out_sum=${NAT_B_SUM%.*}
total_bytes_out_sum=$TOTAL

Métrica: AWS/NATGateway BytesOutToDestination, suma entre los puntos de datos durante
el periodo. El NAT $NAT1 asumió el tráfico cross-AZ del node crossaz en eu-central-1c
(tarea 2) además del tráfico habitual de su propia zona, así que se espera que muestre
un volumen de BytesOutToDestination mayor que $NAT2, que solo sirve a su propia AZ.
EOF
cat /var/work/tests/artifacts/5/natmetrics.txt
```

Si la carga de prueba logró generar tráfico apreciable (por ejemplo, peticiones `curl`
repetidas desde el pod `crossaz`), la diferencia en las sumas ya es visible en la primera
ventana de la métrica; si la carga fue puntual, la diferencia puede ser pequeña - lo que
importa es el hecho de que el NAT que asumió el node cross-AZ muestra un volumen no menor
que el del otro.

## Comprobación rápida

```bash
check_result
```
