[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 128 - solución de referencia (Gateway API en AWS: ALB Gateway API y VPC Lattice)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster. Terraform ya creó los roles IAM para ambos controladores
(componentes `eks_lbc_irsa`, `eks_vpclattice_irsa`) - sus ARN están en
`~/lab128_hints.txt`.

```bash
cat ~/lab128_hints.txt
export CLUSTER=$(kubectl config current-context | sed 's|.*/||')
export LBC_ROLE_ARN=$(grep '^lbc_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export LATTICE_ROLE_ARN=$(grep '^vpclattice_role_arn' ~/lab128_hints.txt | awk '{print $3}')
export NODE_SG=$(grep '^node_sg_id' ~/lab128_hints.txt | awk '{print $3}')
export VPC_ID=$(grep '^vpc_id' ~/lab128_hints.txt | awk '{print $3}')
export ACCOUNT_ID=$(grep '^account_id' ~/lab128_hints.txt | awk '{print $3}')
export REGION=eu-central-1
```

## Tarea 1. CRD de Gateway API y namespaces del laboratorio

```bash
kubectl apply --server-side=true \
  -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

kubectl create namespace eks-128
kubectl create namespace eks-128-backend
```

## Tarea 2. AWS Load Balancer Controller y un Gateway de clase ALB (L7)

```bash
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

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region="${REGION}" \
  --set vpcId="${VPC_ID}"

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system
```

`region` y `vpcId` son obligatorios aquí, y no es algo cosmético. El pod del controlador
cae en `kube-system`, y ese namespace está cubierto por un perfil de Fargate, donde no hay
IMDS en absoluto. Sin estos flags el controlador cae en `CrashLoopBackOff` con
`failed to get VPC ID ... ec2imds: GetMetadata ... context deadline exceeded` (comprobado
en el entorno de pruebas). La misma trampa espera a cualquier controlador que instales en
`kube-system` sobre Fargate (capítulos 15 y 26).

Creamos el `GatewayClass` para ALB y el propio `Gateway`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: aws-alb
spec:
  controllerName: gateway.k8s.aws/alb
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: web
  namespace: eks-128
spec:
  gatewayClassName: aws-alb
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway web -n eks-128 -o wide
```

`gateway.k8s.aws/alb` es el mismo AWS Load Balancer Controller que en los laboratorios
108/109, solo que la entrada se describe con recursos de Gateway API en vez de Ingress:
las rutas L7 `HTTPRoute` y `GRPCRoute` se convierten en listeners y reglas del ALB
(capítulo 28, sección 28.4).

## Tarea 3. HTTPRoute sobre ALB: enrutamiento de la aplicación

```bash
kubectl create deployment frontend --image=viktoruj/ping_pong:latest \
  --replicas=2 -n eks-128
kubectl rollout status deployment/frontend -n eks-128
kubectl expose deployment frontend -n eks-128 --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: app
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - backendRefs:
        - name: frontend
          port: 80
EOF
```

Una sola ruta no es suficiente: hay que indicarle al controlador qué tipo de destinos
registrar. El tipo por defecto se infiere como `instance`, y `instance` requiere un
Service de tipo `NodePort` o `LoadBalancer`. Con `ClusterIP` el balanceador queda
insuficientemente programado: el `Gateway` pasa a `Accepted: False` con
`reason: Invalid`, y en el log del controlador se repite
`TargetGroup port is empty. When using Instance targets, your service must be of type
'NodePort' or 'LoadBalancer'` (reproducido en el entorno de pruebas). En el mundo de
Ingress esto se solucionaba con la anotación `alb.ingress.kubernetes.io/target-type: ip`,
en Gateway API en lugar de una anotación hay un objeto con tipo propio, y debe estar en el
namespace de su propio Service:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: frontend
  namespace: eks-128
spec:
  targetReference:
    name: frontend
  defaultConfiguration:
    targetType: ip
EOF
```

Esperamos la dirección y confirmamos con AWS CLI que es efectivamente un ALB:

```bash
for i in $(seq 1 30); do
  ADDR=$(kubectl get gateway web -n eks-128 -o jsonpath='{.status.addresses[0].value}')
  [[ -n "$ADDR" ]] && break
  sleep 10
done
echo "gateway address: $ADDR"

LB_ARN=$(aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='${ADDR}'].LoadBalancerArn" --output text)

mkdir -p /var/work/tests/artifacts/3
aws elbv2 describe-load-balancers --load-balancer-arns "$LB_ARN" \
  > /var/work/tests/artifacts/3/alb.txt
cat /var/work/tests/artifacts/3/alb.txt
```

En la salida, `Type` debe ser `application` - un `Gateway` de clase `aws-alb` crea un ALB
del mismo modo que un `Ingress` con `ingressClassName: alb` en el laboratorio 109, solo
que mediante un recurso con tipo en vez de anotaciones.

Solo queda esperar a `Programmed: True` y confirmar que el tráfico realmente circula. El
balanceador es interno (`internal-...`), así que la petición se hace desde el worker - está
en la misma VPC:

```bash
for i in $(seq 1 30); do
  p=$(kubectl get gateway web -n eks-128 \
    -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}')
  [[ "$p" == "True" ]] && break
  sleep 10
done
kubectl get gateway web -n eks-128 -o wide

curl -s -o /dev/null -w "http=%{http_code}\n" "http://${ADDR}/"
```

La respuesta `http=200` llega uno o dos minutos después de `Programmed: True`: primero el
ALB se activa, luego los destinos pasan el health check (el estado de los destinos se ve
con `aws elbv2 describe-target-health`).

## Tarea 4. AWS Gateway API Controller y un Gateway de clase VPC Lattice

Primero abrimos el SG de los nodos para el tráfico de VPC Lattice - sin esta regla los
pods no recibirán tráfico de la Service Network (capítulo 28, sección 28.4 de la
documentación de despliegue del controlador):

```bash
PREFIX_LIST_ID=$(aws ec2 describe-managed-prefix-lists \
  --query "PrefixLists[?PrefixListName=='com.amazonaws.eu-central-1.vpc-lattice'].PrefixListId" \
  --output text)

aws ec2 authorize-security-group-ingress --group-id "$NODE_SG" \
  --ip-permissions "PrefixListIds=[{PrefixListId=${PREFIX_LIST_ID}}],IpProtocol=-1"
```

Instalamos el controlador: namespace, ServiceAccount con el rol, chart de Helm con el
parámetro `defaultServiceNetwork` - el propio controlador creará la Service Network
`eks-task128-mesh` y asociará con ella la VPC del clúster. El chart y la imagen están en
un ECR público y se descargan de forma anónima, no se necesita `helm registry login` (el
rol del worker no tiene `ecr-public:GetAuthorizationToken`, y eso es correcto - un
registro público se lee sin token):

```bash
kubectl create namespace aws-application-networking-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gateway-api-controller
  namespace: aws-application-networking-system
  annotations:
    eks.amazonaws.com/role-arn: ${LATTICE_ROLE_ARN}
EOF

helm install gateway-api-controller \
  oci://public.ecr.aws/aws-application-networking-k8s/aws-gateway-controller-chart \
  --version=v1.1.0 \
  --namespace aws-application-networking-system \
  --set=serviceAccount.create=false \
  --set=defaultServiceNetwork=eks-task128-mesh \
  --set=awsRegion="${REGION}" \
  --set=awsAccountId="${ACCOUNT_ID}" \
  --set=clusterVpcId="${VPC_ID}" \
  --set=clusterName="${CLUSTER}"

kubectl rollout status deployment -n aws-application-networking-system --timeout=180s
```

Estos cuatro últimos flags son obligatorios por la misma razón que `region` y `vpcId` en
el LBC, pero el síntoma es distinto y conviene recordarlo. El pod de este controlador se
ejecuta en un nodo EC2 normal, es decir que IMDS existe en principio, pero IMDSv2 va con
hop limit 1, y la petición desde el namespace de red del pod se descarta. Sin los flags el
controlador falla al instante con
`init config failed: vpcId is not specified: EC2MetadataError ... status code: 401`
(comprobado en el entorno de pruebas). Exactamente este hop limit se trata en los
capítulos 10 y 19: protege las credenciales del rol del nodo frente a los pods, y de paso
rompe cualquier controlador que confíe en los metadatos.

Creamos el `GatewayClass` para VPC Lattice y el propio `Gateway`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: GatewayClass
metadata:
  name: amazon-vpc-lattice
spec:
  controllerName: application-networking.k8s.aws/gateway-api-controller
EOF

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eks-task128-mesh
  namespace: eks-128
spec:
  gatewayClassName: amazon-vpc-lattice
  listeners:
    - name: http
      protocol: HTTP
      port: 80
EOF

kubectl get gateway eks-task128-mesh -n eks-128 -o wide
```

El nombre del `Gateway` aquí no es arbitrario, y esa es la principal trampa de la tarea.
El controlador de VPC Lattice busca la Service Network por el NOMBRE del objeto `Gateway`,
no por el valor de `defaultServiceNetwork`. Llama al `Gateway` `mesh` y se quedará para
siempre en `Programmed: False` con el mensaje `VPC Lattice Service Network not found`,
porque la red en la cuenta se llama `eks-task128-mesh` (comprobado en el entorno de
pruebas: dos `Gateway` uno junto al otro, el de nombre coincidente muestra
`Programmed: True` y el ARN de la red en el mensaje, el de nombre distinto muestra
`not found`). De ahí la regla: nombre del `Gateway` = nombre de la Service Network.

Un `Gateway` de clase `amazon-vpc-lattice` se refleja en una Service Network de VPC
Lattice: es una conexión east-west entre servicios del clúster, no una entrada desde el
exterior como `aws-alb` (capítulo 28, sección 28.5).

## Tarea 5. Síntoma: HTTPRoute sin ReferenceGrant

Levantamos el backend en un namespace vecino:

```bash
kubectl create deployment backend --image=viktoruj/ping_pong:latest \
  --replicas=1 -n eks-128-backend
kubectl rollout status deployment/backend -n eks-128-backend
kubectl expose deployment backend -n eks-128-backend --port=80 --target-port=8080

cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.k8s.aws/v1
kind: TargetGroupConfiguration
metadata:
  name: backend
  namespace: eks-128-backend
spec:
  targetReference:
    name: backend
  defaultConfiguration:
    targetType: ip
EOF
```

`TargetGroupConfiguration` se necesita por la misma razón que en la tarea 3, y además
muestra la separación de propiedad: el objeto vive en el namespace del propietario del
Service, no junto a la ruta.

La ruta `rates` vive en `eks-128`, pero hace referencia a un Service en
`eks-128-backend`. Su padre es el `Gateway` `web` de clase `aws-alb`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: web
      sectionName: http
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /rates
      backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF
```

La misma ruta, pero sobre un `Gateway` de clase `amazon-vpc-lattice` - este es el
experimento de control, necesario para la conclusión de la tarea:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: rates-lattice
  namespace: eks-128
spec:
  parentRefs:
    - kind: Gateway
      name: eks-task128-mesh
      sectionName: http
  rules:
    - backendRefs:
        - name: backend
          namespace: eks-128-backend
          port: 80
EOF

sleep 25
mkdir -p /var/work/tests/artifacts/5
{
  echo "rates status=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates reason=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
  echo "rates message=$(kubectl get httproute rates -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].message}')"
  echo "rates-lattice status=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "rates-lattice reason=$(kubectl get httproute rates-lattice -n eks-128 -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].reason}')"
} > /var/work/tests/artifacts/5/refnotpermitted.txt
cat /var/work/tests/artifacts/5/refnotpermitted.txt
```

No usamos `kubectl -o yaml | grep -A...`: en los objetos CRD (unstructured), los campos de
condition se serializan en orden alfabético (`reason`, `status` van antes que `type`), así
que es más fiable extraer la condición necesaria directamente con `jsonpath`.

Un `backendRefs` con el campo `namespace` hace referencia a un Service en otro namespace -
por defecto esa referencia está prohibida, para que un desarrollador de `eks-128` no pueda
dirigir tráfico hacia un servicio ajeno sin el permiso de su propietario (capítulo 28,
sección 28.2). Para la ruta `rates` la condición `ResolvedRefs` será `status: "False"`,
`reason: RefNotPermitted`, mensaje
`No explicit ReferenceGrant exists to allow the reference.`

Pero he aquí el resultado en el que se centra el experimento de control: la condición de
`rates-lattice` es de inmediato `ResolvedRefs: True`, aunque todavía no existe ningún
`ReferenceGrant` en `eks-128-backend` (comprobado en el entorno de pruebas). La regla
`ReferenceGrant` forma parte de la especificación de Gateway API, pero es la
implementación quien la RESPETA, no el API server: el AWS Load Balancer Controller la
comprueba, el controlador de VPC Lattice versión v1.1.0 no. De ahí la conclusión
práctica: el mismo YAML en dos implementaciones de Gateway API da una frontera de
confianza distinta entre equipos, y solo se puede confiar en `ReferenceGrant` como
protección allí donde has comprobado el comportamiento del controlador.

## Tarea 6. Fix: ReferenceGrant permite la referencia entre namespace

`ReferenceGrant` lo crea el propietario del backend de **destino** - el namespace
`eks-128-backend`, no quien hace la referencia:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-from-eks-128
  namespace: eks-128-backend
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: eks-128
  to:
    - group: ""
      kind: Service
EOF

sleep 15
mkdir -p /var/work/tests/artifacts/6
{
  echo "ResolvedRefs status=$(kubectl get httproute rates -n eks-128 \
    -o jsonpath='{.status.parents[0].conditions[?(@.type=="ResolvedRefs")].status}')"
  echo "curl /rates http=$(curl -s -o /dev/null -w '%{http_code}' -m 10 "http://${ADDR}/rates")"
} > /var/work/tests/artifacts/6/resolved.txt
cat /var/work/tests/artifacts/6/resolved.txt
```

En la segunda línea del artefacto comprobamos no el estado, sino el tráfico en sí:
`http=200` desde el pod `backend` significa que toda la cadena se ha completado - la ruta
fue permitida por el grant, se creó la target group de tipo `ip`, y los destinos pasaron
el health check. Si `ResolvedRefs` ya es `True` pero `curl` devuelve `503`, espera un
minuto: el registro de destinos ocurre después de que aparece la target group.

Tras la aparición del `ReferenceGrant`, la condición `ResolvedRefs` de `rates` cambia a
`True` en pocos segundos - el controlador reevalúa las referencias permitidas en la
siguiente reconciliación, y la ruta empieza a resolver `backend` en el namespace vecino.
Fíjate en que el permiso lo otorga el namespace PROPIETARIO del destino: elimina el
`ReferenceGrant`, y la ruta vuelve a `RefNotPermitted`, aunque nadie haya tocado la ruta
en sí.

## Comprobación rápida

```bash
check_result
```
