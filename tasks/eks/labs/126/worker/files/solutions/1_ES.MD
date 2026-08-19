[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 126 - solución de referencia (security groups for pods)

Todos los comandos corren en la máquina de trabajo por SSH, igual que en el resto de labs
del curso: el rol del worker recibió permisos para crear una security group, añadirle
reglas, y adjuntar la política `AmazonEKSVPCResourceController` al rol del clúster (ver
el README, sección "Infraestructura").

Variables compartidas en toda la solución:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
REGION=eu-central-1
VPC_ID=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "cluster=$CLUSTER vpc=$VPC_ID"
```

## Tarea 1. Namespace `eks-126`

```bash
kubectl create namespace eks-126
```

## Tarea 2. Verificación de los prerrequisitos

Encuentra el nombre del rol del control plane y verifica las políticas adjuntas (en el
worker):

```bash
ROLE_ARN=$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.roleArn' --output text)
ROLE_NAME=$(echo "$ROLE_ARN" | sed 's|.*/||')
echo "cluster role: $ROLE_NAME"
aws iam list-attached-role-policies --role-name "$ROLE_NAME"
```

Por defecto no está ahí (el rol solo tiene `AmazonEKSClusterPolicy` y la política de
cifrado), así que la adjuntamos:

```bash
aws iam attach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSVPCResourceController
```

La política va en el rol del **control plane** (el clúster), no en el rol del nodo de
Karpenter - es el que permite que EKS cree/elimine branch ENI y gestione sus IP.

Verificamos las tres variables de VPC CNI - todas ya configuradas por terraform mediante
la `configuration` del addon `vpc-cni`:

```bash
kubectl describe daemonset aws-node -n kube-system \
  | grep -E 'ENABLE_POD_ENI|POD_SECURITY_GROUP_ENFORCING_MODE|DISABLE_TCP_EARLY_DEMUX'
```

Salida esperada: `ENABLE_POD_ENI: true`, `POD_SECURITY_GROUP_ENFORCING_MODE: strict`,
`DISABLE_TCP_EARLY_DEMUX: true`. La primera activa la trunk interface, la segunda mantiene
activa la comprobación de reglas de SG del pod para el tráfico desde el nodo (en modo
`standard` no lo estaría, y el síntoma de la tarea 4 no aparecería), la tercera permite
que `kubelet` abra una conexión TCP a un pod en una branch ENI.

Guarda ambas confirmaciones:

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "cluster role: $ROLE_NAME"
  aws iam list-attached-role-policies --role-name "$ROLE_NAME"
  echo "---"
  kubectl describe daemonset aws-node -n kube-system | grep ENABLE_POD_ENI
} > /var/work/tests/artifacts/2/prereqs.txt
cat /var/work/tests/artifacts/2/prereqs.txt
```

## Tarea 3. Una security group incompleta y SecurityGroupPolicy

Crea la SG en la VPC de la lab. Importante: NO le pongas la etiqueta
`karpenter.sh/discovery`, de lo contrario el EC2NodeClass la tomaría como SG de nodo:

```bash
SG_ID=$(aws ec2 create-security-group \
  --group-name eks-task126-secured-pod-sg \
  --description "security group for secured-app pods (lab 126, intentionally incomplete)" \
  --vpc-id "$VPC_ID" \
  --query 'GroupId' --output text)
echo "$SG_ID"
```

Todavía no añadimos ningún `authorize-security-group-ingress` ni `egress`: una SG recién
creada solo tiene el allow-all egress por defecto de AWS y cero reglas inbound -
exactamente el estado que produce el síntoma.

Crea el `SecurityGroupPolicy`:

```bash
mkdir -p /var/work/tests/artifacts/3
echo -n "$SG_ID" > /var/work/tests/artifacts/3/sg_id.txt

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: secured-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: secured
  securityGroups:
    groupIds:
      - ${SG_ID}
EOF

kubectl get securitygrouppolicy secured-sgp -n eks-126 -o yaml
```

## Tarea 4. El síntoma: Running, pero nunca Ready

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secured-app
  namespace: eks-126
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secured
  template:
    metadata:
      labels:
        app: secured
    spec:
      nodeSelector:
        work_type: nitro
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          periodSeconds: 5
          failureThreshold: 3
EOF

kubectl rollout status deployment/secured-app -n eks-126 --timeout=180s || true
kubectl get pod -n eks-126 -l app=secured
```

El pod se queda en `0/1 Ready`, aunque la fase sea `Running` - la branch ENI se creó, pero
la SG del pod no deja pasar la probe de kubelet. Guarda el diagnóstico:

```bash
mkdir -p /var/work/tests/artifacts/4
POD=$(kubectl get pod -n eks-126 -l app=secured -o jsonpath='{.items[0].metadata.name}')
kubectl describe pod "$POD" -n eks-126 > /var/work/tests/artifacts/4/pod_not_ready.txt
grep -i 'readiness probe failed\|unhealthy' /var/work/tests/artifacts/4/pod_not_ready.txt
```

El evento se ve así (verificado en el banco de pruebas):

```
Warning  Unhealthy  49s (x33 over 5m44s)  kubelet  Readiness probe failed:
Get "http://10.10.16.177:8080/": context deadline exceeded
```

Confirmamos que el pod realmente está en una branch ENI, no en la ENI del nodo:

```bash
kubectl get pod "$POD" -n eks-126 \
  -o jsonpath='{.metadata.annotations.vpc\.amazonaws\.com/pod-eni}{"\n"}'
kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.containers[0].resources.limits}{"\n"}'
aws ec2 describe-network-interfaces --filters "Name=group-id,Values=$SG_ID" \
  --query 'NetworkInterfaces[].[NetworkInterfaceId,InterfaceType,Status,PrivateIpAddress]' \
  --output text
```

La anotación contendrá `eniId`, `vlanId` y un `associationID` como
`trunk-assoc-...`, los límites mostrarán `vpc.amazonaws.com/pod-eni: 1`, y el tipo de
interfaz será `branch` con la misma IP que el pod.

## Tarea 5. Arreglando las probes: una regla inbound desde la SG del nodo

Encuentra la SG del nodo de Karpenter a través del nodo donde corre `secured-app` (en el
worker):

```bash
NODE=$(kubectl get pod "$POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
INSTANCE_ID=$(kubectl get node "$NODE" -o jsonpath='{.spec.providerID}' | sed 's|.*/||')
NODE_SG=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
echo "node=$NODE instance=$INSTANCE_ID node_sg=$NODE_SG"
```

Añade una regla inbound a la SG del pod:

```bash
aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --protocol tcp --port 8080 \
  --source-group "$NODE_SG"
```

Espera a que la probe pase y guarda el resultado:

```bash
sleep 15
kubectl get pod -n eks-126 -l app=secured
mkdir -p /var/work/tests/artifacts/5
kubectl get pod "$POD" -n eks-126 > /var/work/tests/artifacts/5/pod_ready.txt
cat /var/work/tests/artifacts/5/pod_ready.txt
```

`READY` ahora debería mostrar `1/1` - kubelet ya puede alcanzar la branch ENI del pod en
el puerto de la probe.

## Tarea 6. Diagnosticando y arreglando DNS

Verifica la resolución desde dentro de `secured-app`. La imagen `viktoruj/ping_pong:latest`
no tiene utilidades de shell para DNS (construida desde `scratch`), así que usamos un pod
de diagnóstico separado con la misma etiqueta `app: secured`, para que `secured-sgp`
también se le aplique:

```bash
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never \
  --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  -- sleep 3600
kubectl wait --for=condition=Ready pod/dns-probe -n eks-126 --timeout=120s || true

mkdir -p /var/work/tests/artifacts/6
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_before.txt 2>&1 || true
cat /var/work/tests/artifacts/6/dns_before.txt
```

La salida es `;; connection timed out; no servers could be reached`. Es importante
identificar correctamente la causa: aquí el egress no es el problema, una SG recién
creada tiene la regla de allow-all egress por defecto, y la solicitud sale bien. El
paquete se descarta del lado inbound de la parte receptora, que no tiene ninguna regla
para nuestra SG. CoreDNS en esta lab corre en Fargate y está detrás de la cluster primary
security group:

```bash
CLUSTER_PRIMARY_SG=$(aws eks describe-cluster --name "$CLUSTER" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
echo "cluster primary sg (CoreDNS on Fargate): $CLUSTER_PRIMARY_SG"
```

Añadimos un inbound `53` TCP y UDP a la cluster primary SG, con el origen siendo la SG de
nuestro pod. Esta única regla es suficiente, ya que una security group es stateful: la
respuesta a una solicitud inbound permitida vuelve sin una regla separada.

```bash
aws ec2 authorize-security-group-ingress --group-id "$CLUSTER_PRIMARY_SG" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$SG_ID}]"
```

Verificamos la resolución de nuevo:

```bash
sleep 5
kubectl exec dns-probe -n eks-126 -- nslookup kubernetes.default.svc.cluster.local \
  > /var/work/tests/artifacts/6/dns_after.txt 2>&1
cat /var/work/tests/artifacts/6/dns_after.txt
```

Ahora el segundo paso, siguiendo el mínimo privilegio. El allow-all egress por defecto de
la SG del pod significa "el pod tiene permitido cualquier cosa saliente" - para un pod con
su propia security group, eso es exactamente lo que intentábamos evitar. Reducimos el
egress a `53` y confirmamos que el DNS sigue funcionando:

```bash
aws ec2 revoke-security-group-egress --group-id "$SG_ID" \
  --protocol -1 --port all --cidr 0.0.0.0/0
aws ec2 authorize-security-group-egress --group-id "$SG_ID" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]" \
    "IpProtocol=udp,FromPort=53,ToPort=53,UserIdGroupPairs=[{GroupId=$CLUSTER_PRIMARY_SG}]"

kubectl delete pod dns-probe -n eks-126 --ignore-not-found
kubectl run dns-probe -n eks-126 --image=busybox --restart=Never --labels='app=secured' \
  --overrides='{"spec":{"nodeSelector":{"work_type":"nitro"}}}' \
  --command -- sh -c 'nslookup kubernetes.default.svc.cluster.local'
sleep 45
kubectl logs dns-probe -n eks-126 | tee -a /var/work/tests/artifacts/6/dns_after.txt
```

Construye el artefacto:

```bash
cat > /var/work/tests/artifacts/6/dns_fix.txt <<EOF
Antes de la corrección (dns_before.txt): nslookup a kubernetes.default falló con
";; connection timed out; no servers could be reached".

La causa NO es el egress: una security group recién creada ${SG_ID} tiene la regla de
allow-all egress por defecto, y la solicitud desde el pod sale bien. El paquete se
descarta del lado INBOUND de la parte receptora - la cluster primary security group
${CLUSTER_PRIMARY_SG}, detrás de la cual corre CoreDNS en Fargate, no tiene ninguna regla
inbound para nuestra SG. La regla se necesita justo ahí, y una es suficiente: una
security group es stateful, la respuesta a una solicitud inbound permitida vuelve por su
cuenta.

Corrección: inbound 53 TCP y UDP en ${CLUSTER_PRIMARY_SG} con source-group ${SG_ID}.
Después de eso, nslookup resuelve kubernetes.default.svc.cluster.local (dns_after.txt).

Segundo paso: se eliminó el allow-all egress por defecto de la SG del pod, reemplazado
por un egress explícito 53 TCP y UDP hacia ${CLUSTER_PRIMARY_SG}. El DNS sigue
funcionando - esto muestra que el egress del lado origen y el inbound del lado receptor
son dos reglas independientes, y permitir al pod todo el tráfico saliente no es
necesario para el DNS.
EOF
cat /var/work/tests/artifacts/6/dns_fix.txt
```

## Tarea 7. Trampa: un nodo, security groups diferentes

Ejecuta un experimento: dos pods con security groups DIFERENTES en el mismo nodo.
Configura una segunda SG y un segundo `SecurityGroupPolicy` para la etiqueta `app: other`:

```bash
mkdir -p /var/work/tests/artifacts/7
SG2=$(aws ec2 create-security-group \
  --group-name eks-task126-other-pod-sg \
  --description "second pod sg for the same-node experiment (lab 126)" \
  --vpc-id "$VPC_ID" --query 'GroupId' --output text)
echo "second pod sg: $SG2"

cat <<EOF | kubectl apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: other-sgp
  namespace: eks-126
spec:
  podSelector:
    matchLabels:
      app: other
  securityGroups:
    groupIds:
      - ${SG2}
EOF
```

Encontramos el pod del Deployment (ese en concreto, no los pods de diagnóstico - también
llevan la etiqueta `app: secured`) e iniciamos un pod con una SG diferente junto a él:

```bash
APP_POD=$(kubectl get pod -n eks-126 -l app=secured \
  -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].kind=="ReplicaSet")]}{.metadata.name}{"\n"}{end}' \
  | head -1)
APP_IP=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.status.podIP}')
APP_NODE=$(kubectl get pod "$APP_POD" -n eks-126 -o jsonpath='{.spec.nodeName}')
echo "secured-app=$APP_POD ip=$APP_IP node=$APP_NODE"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/before.txt
```

El resultado es `wget: download timed out`: el pod tiene su propia SG, el vecino tiene la
suya, y no hay ninguna regla que permita el tráfico entre ellos. Añade la regla y repite:

```bash
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
  --protocol tcp --port 8080 --source-group "$SG2"

kubectl delete pod othersg -n eks-126 --ignore-not-found --wait=true
kubectl run othersg -n eks-126 --image=busybox --restart=Never --labels='app=other' \
  --overrides="{\"spec\":{\"nodeName\":\"$APP_NODE\"}}" \
  --command -- sh -c "wget -T 10 -qO- http://$APP_IP:8080/ ; echo RC=\$?"
sleep 55
kubectl logs othersg -n eks-126 | tee /var/work/tests/artifacts/7/after.txt
```

Ahora la solicitud pasa (`RC=0`). Esto significa que en modo `strict`, las reglas de la SG
del pod se aplican incluso dentro de un solo nodo - ambos pods tienen sus propias branch
ENI, y es la regla la que decide el resultado. Construye el artefacto:

```bash
{
  echo "=== Deployment's pod with SecurityGroupPolicy secured-sgp (branch ENI) ==="
  kubectl get pod "$APP_POD" -n eks-126 -o wide
  echo
  echo "=== pod with a DIFFERENT security group (other-sgp), same node ==="
  kubectl get pod othersg -n eks-126 -o wide
  echo
  echo "=== before the rule ==="
  cat /var/work/tests/artifacts/7/before.txt
  echo "=== after the inbound 8080 rule from the second SG ==="
  cat /var/work/tests/artifacts/7/after.txt
  echo
  echo "=== where CoreDNS is ==="
  kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
  cat <<'TXT'

Conclusión del experimento. Nuestro POD_SECURITY_GROUP_ENFORCING_MODE es strict, y en él
las reglas de la security group del pod se aplican incluso al tráfico dentro de un solo
nodo: dos pods con SG diferentes en el mismo nodo primero no lograron conectarse (download
timed out), y tras añadir una regla inbound se conectaron. Así que el diagnóstico aquí es
el habitual - mirar las reglas, no la topología.

El contraste que vale la pena conocer (documentación de AWS, modo standard): en modo
standard, las reglas de SG del pod NO se aplican al tráfico entre pods y servicios en el
mismo nodo, incluyendo kubelet y nodeLocalDNS, y los pods con security groups diferentes
en el mismo nodo no se comunican en absoluto, porque están en subredes distintas con el
enrutamiento deshabilitado entre ellas. Ahí, la misma situación no se puede arreglar con
una regla, solo distribuyendo los pods entre nodos. Por eso mismo standard tampoco
reproduce el síntoma de las tareas 4 y 5: la probe de kubelet evita las reglas de SG, y la
readiness pasa incluso con una security group que no tiene una sola regla inbound.
TXT
} > /var/work/tests/artifacts/7/same_node_trap.txt
cat /var/work/tests/artifacts/7/same_node_trap.txt
```

## Verificación rápida

```bash
check_result
```
