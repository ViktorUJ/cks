[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 103 - solución de referencia (plan de direcciones: ENI, prefix delegation, secondary CIDR)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster (el kubeconfig se genera mediante `aws eks
update-kubeconfig` al arrancar la máquina).

```bash
export CLUSTER=$(aws eks list-clusters --query 'clusters[0]' --output text)
kubectl create namespace eks-103
```

## Tarea 1. Cálculo de max-pods con la fórmula y comprobación con el valor real

Creamos la carga base y esperamos a que Karpenter levante para ella un nodo EC2 en el modo
normal (por dirección) de VPC CNI - el add-on todavía no está pasado a prefix delegation:

```bash
kubectl create deployment baseline --image=viktoruj/ping_pong:latest --replicas=2 -n eks-103
kubectl rollout status deployment/baseline -n eks-103

NODE=$(kubectl get po -n eks-103 -l app=baseline -o jsonpath='{.items[0].spec.nodeName}')
TYPE=$(kubectl get node "$NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
echo "node=$NODE type=$TYPE"
```

Obtenemos el número de ENI, las IP por ENI y las vCPU para ese tipo de instancia:

```bash
ENI=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkInterfaces' --output text)
IPS=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].NetworkInfo.Ipv4AddressesPerInterface' --output text)
VCPU=$(aws ec2 describe-instance-types --instance-types "$TYPE" \
  --query 'InstanceTypes[0].VCpuInfo.DefaultVCpus' --output text)
echo "eni=$ENI ips_per_eni=$IPS vcpu=$VCPU"
```

Calculamos con la fórmula `max-pods = ENI * (IP por ENI - 1) + 2` y aplicamos el tope del
managed node group (`110` si `vCPU < 30`, si no `250`):

```bash
FORMULA=$((ENI * (IPS - 1) + 2))
if [ "$VCPU" -lt 30 ]; then CAP=110; else CAP=250; fi
if [ "$FORMULA" -lt "$CAP" ]; then EXPECTED=$FORMULA; else EXPECTED=$CAP; fi
echo "formula=$FORMULA cap=$CAP expected_max_pods=$EXPECTED"

ACTUAL=$(kubectl get node "$NODE" -o jsonpath='{.status.allocatable.pods}')
echo "actual_allocatable_pods=$ACTUAL"
```

Ejemplo para `m5.large`: `ENI=3`, `IP por ENI=10` dan `formula = 3*(10-1)+2 = 29`, el tope
`110` no interviene (`29 < 110`), así que `expected_max_pods = 29` - y eso es exactamente lo
que debe mostrar `kubectl get node`.

Guardamos el cálculo y el valor real en el artefacto:

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

Si `expected_max_pods` y `actual_allocatable_pods` no coinciden - kubelet solo conoce
max-pods al arrancar el nodo, así que la comprobación debe hacerse sobre un nodo que ya
esté completamente Ready.

## Tarea 2. Prefix delegation: nodo nuevo frente a nodo antiguo

Fijamos el estado del nodo antiguo (modo por dirección) antes de activar prefix
delegation:

```bash
OLD_NODE="$NODE"
OLD_PODS=$(kubectl get node "$OLD_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "old_node=$OLD_NODE old_node_allocatable_pods=$OLD_PODS"
```

Activamos prefix delegation en el add-on gestionado `vpc-cni` (solo funciona en instancias
basadas en Nitro, por eso importa que el NodePool use esos tipos):

```bash
aws eks update-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --configuration-values '{"env":{"ENABLE_PREFIX_DELEGATION":"true","WARM_PREFIX_TARGET":"1"}}' \
  --resolve-conflicts PRESERVE

aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
  --query 'addon.configurationValues'
```

Prefix delegation solo afecta a los nodos nuevos: el nodo antiguo `baseline` ya recibió su
límite `allocatable.pods` de kubelet al arrancar y no lo recalculará hasta que sea
recreado. Provocamos la creación de un nodo nuevo con una carga que no cabe en el antiguo:

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

Identificamos el nodo nuevo y comparamos los límites:

```bash
NEW_NODE=$(kubectl get po -n eks-103 -l app=scale -o jsonpath='{.items[*].spec.nodeName}' \
  | tr ' ' '\n' | grep -v "^${OLD_NODE}$" | head -n1)
NEW_TYPE=$(kubectl get node "$NEW_NODE" \
  -o jsonpath='{.metadata.labels.node\.kubernetes\.io/instance-type}')
NEW_PODS=$(kubectl get node "$NEW_NODE" -o jsonpath='{.status.allocatable.pods}')
echo "new_node=$NEW_NODE new_node_instance_type=$NEW_TYPE new_node_allocatable_pods=$NEW_PODS"
```

Ejemplo para `m5.large` en modo de prefijos: el límite salta de `29` a `434` (topado por el
tope del managed node group `110`, así que el techo real es `110`, pero sigue siendo mucho
más que el `29` del modo por dirección).

Guardamos la comparación y la explicación en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/prefixdelegation.txt <<EOF
old_node=$OLD_NODE
old_node_allocatable_pods=$OLD_PODS
new_node=$NEW_NODE
new_node_instance_type=$NEW_TYPE
new_node_allocatable_pods=$NEW_PODS

old_node_allocatable_pods no cambió porque kubelet calcula max-pods una sola vez, al
arrancar el nodo, y prefix delegation solo afecta a los nodos nuevos, no a los que ya
están en marcha. new_node se creó después de activar prefix delegation, así que sus ENI
ocupan prefijos /28 (16 direcciones cada uno) en lugar de IP individuales, y el límite de
pods es visiblemente mayor.
EOF
cat /var/work/tests/artifacts/2/prefixdelegation.txt
```

## Tarea 3. Planificación del tamaño de la subred para el crecimiento

Calculamos la necesidad final: `850` pods, margen del `20%` para el warm pool, después
otro `15%` para el rolling update (los márgenes se multiplican de forma secuencial):

```bash
python3 - <<'EOF'
base = 850
after_warm = base * 1.20
after_roll = after_warm * 1.15
print(f"base={base} after_warm_pool={after_warm:.0f} after_rolling_update={after_roll:.0f}")
EOF
```

Resultado: `850 * 1.20 = 1020`, `1020 * 1.15 = 1173` - la necesidad final es de
aproximadamente `1173` direcciones. Comparamos con la tabla de direcciones disponibles por
prefijo de subred (AWS reserva `5` direcciones por subred):

- `/24` - total `256`, disponibles `251` - menos que `1173`, no vale;
- `/22` - total `1024`, disponibles `1019` - también menos que `1173`, no vale;
- `/20` - total `4096`, disponibles `4091` - sobra con mucho margen.

`4091 / 1173 ≈ 3.5` veces de margen, que cubre tanto el cálculo actual como el crecimiento
futuro, por eso elegimos `/20`.

```bash
mkdir -p /var/work/tests/artifacts/3
cat > /var/work/tests/artifacts/3/cidrplan.txt <<'EOF'
Necesidad: 850 pods * 1.20 (margen para warm pool) * 1.15 (margen para rolling update)
= 1173 direcciones (necesidad final de direcciones).

/24 (total 256, disponibles 251) - no vale, disponible es menor que la necesidad.
/22 (total 1024, disponibles 1019) - no vale, disponible es menor que la necesidad (1173).
/20 (total 4096, disponibles 4091) - vale: 4091 / 1173 ~= 3.5 veces de margen.

Elección: /20. El warm pool de Karpenter y un rolling update simultáneo mantienen
brevemente direcciones extra ocupadas, por eso la subred debe ser notablemente mayor que
el pico puntual, no quedarse al límite de 1173 direcciones.
EOF
cat /var/work/tests/artifacts/3/cidrplan.txt
```

## Tarea 4. Secondary CIDR: ampliamos el plan de direcciones de la VPC

Averiguamos el `vpc-id` del clúster y conectamos un secondary CIDR del shared address
space de RFC 6598 (`100.64.0.0/16` no se solapa con el CIDR primario `10.10.0.0/16` de
esta VPC):

```bash
VPC=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.vpcId' --output text)

aws ec2 associate-vpc-cidr-block --vpc-id "$VPC" --cidr-block 100.64.0.0/16
```

Esperamos al estado `associated` (justo después de la llamada el bloque puede estar en
`associating`):

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

Creamos una subred en el bloque nuevo:

```bash
SUBNET=$(aws ec2 create-subnet --vpc-id "$VPC" --cidr-block 100.64.1.0/24 \
  --availability-zone eu-central-1a --query 'Subnet.SubnetId' --output text)
echo "subnet=$SUBNET"
```

Guardamos el resultado en el artefacto:

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

Si en lugar de `100.64.0.0/16` probáramos `172.16.0.0/12` o `192.168.0.0/16` - AWS no
permitiría añadirlos a una VPC cuyo CIDR primario ya está en el rango `10.0.0.0/8`
(solapamiento entre rangos privados de RFC 1918), por eso normalmente se usa
precisamente RFC 6598.

## Tarea 5. Diagnóstico de escasez de direcciones (sin un fallo real)

No tocamos la infraestructura del laboratorio: no recortamos subredes ni agotamos
direcciones de forma artificial. Miramos el estado actual de las subredes del clúster -
son los mismos comandos con los que se diagnostica la escasez de direcciones en un
clúster real:

```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' \
  --output table
```

Guardamos la explicación del diagnóstico de escasez de direcciones en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/diagnostics.txt <<'EOF'
Cómo diagnosticar la escasez de direcciones IP en un clúster real:

1. Síntoma en el pod: kubectl describe pod mostrará en Events el evento
   FailedCreatePodSandBox de aws-cni - esta es la primera señal de que VPC CNI no
   pudo asignar una dirección.

2. Escasez general de direcciones en una subred: aws ec2 describe-subnets --query
   'Subnets[].[SubnetId,AvailabilityZone,CidrBlock,AvailableIpAddressCount]' - si
   AvailableIpAddressCount de esa AZ es 0, es un diagnóstico directo de agotamiento
   de direcciones en esa subred y esa AZ.

3. Fragmentación en lugar de escasez real: si prefix delegation está activado pero no
   hay un bloque contiguo /28 en la subred (las direcciones están dispersas en IP
   individuales ocupadas), en los logs de ipamd/aws-node aparecerá un error
   InsufficientCidrBlocks, incluso cuando el AvailableIpAddressCount de la subred
   parezca grande. Son causas distintas del mismo síntoma externo (un pod no puede
   obtener dirección), y se solucionan de forma distinta: la escasez de direcciones se
   soluciona ampliando el CIDR o añadiendo un secondary CIDR (tarea 4), la
   fragmentación se soluciona liberando espacio para un bloque contiguo o creando una
   subred nueva.
EOF
cat /var/work/tests/artifacts/5/diagnostics.txt
```

## Verificación rápida

```bash
check_result
```
