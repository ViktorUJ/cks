[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 132 - solución de referencia (Cilium en modo CNI chaining sobre VPC CNI)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl y helm ya
están configurados (el kubeconfig se construyó mediante `aws eks update-kubeconfig` al
arrancar la máquina).

> Las versiones de Cilium y los nombres exactos de los flags de values del modo chaining
> cambian rápido entre releases. Los comandos siguientes se han verificado en un banco en
> vivo con Cilium `1.20.0` y EKS `1.36`. Si usas otra versión, comprueba la sintaxis con la
> documentación de Cilium
> (`https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/`).

## Tarea 1. Namespace `eks-132`

```bash
kubectl create namespace eks-132
```

## Tarea 2. Carga en el pool `cilium-demo` sin Cilium

El NodePool `cilium-demo` ya existe como código (taint `dedicated=cilium-demo:NoSchedule`,
etiqueta `work_type=cilium-demo`), pero hasta que no llegue un pod con toleration, Karpenter
no levantará ningún nodo. Creamos el Deployment `api` y `client` directamente con
`nodeSelector` y toleration, para que caigan exactamente ahí:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: eks-132
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: eks-132
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: eks-132
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: curl
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Karpenter levanta un nuevo nodo en el pool `cilium-demo` (normalmente 60-90 segundos). En
cuanto `rollout status` confirma la disponibilidad, comprobamos la conectividad mediante el
VPC CNI estándar - Cilium aún no está instalado:

```bash
mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
cat /var/work/tests/artifacts/2/connectivity_before.txt
```

## Tarea 3. Cilium mediante Helm en modo CNI chaining, solo en `cilium-demo`

Añadimos el repositorio de Cilium y preparamos el archivo de values. El parámetro clave es
`cni.chainingMode: aws-cni`: VPC CNI (`aws-node`) sigue siendo el IPAM principal, Cilium se
conecta en la cadena y añade programas eBPF encima de la interfaz del pod ya configurada.

Tres bloques `nodeSelector`/`tolerations` (nivel superior para el agente, `envoy` y
`operator`) restringen todos los componentes de Cilium al pool `cilium-demo`. El
`nodeSelector` de nivel superior solo lo hereda el DaemonSet `cilium`; `cilium-envoy` y
`cilium-operator` tienen sus propias secciones, y sin ellas los pods de Envoy se quedan
colgados en `Pending` en todos los demás nodos, y `cilium status` mostrará
`Envoy DaemonSet: 1 errors`.

Aparte desactivamos `operator.unmanagedPodWatcher.restart`. Este flag es obligatorio para
este banco, no un ajuste fino: por defecto el operador elimina cada 15 segundos los pods
que no tienen `CiliumEndpoint`, para que se reinicien y entren en la cadena de CNI. Los
pods `coredns` viven en Fargate, donde no hay ni puede haber agente de Cilium, así que
nunca llegarán a ser managed - el operador los mata sin fin, levantando cada vez un nuevo
nodo Fargate, y el DNS del clúster se cae (detalles en la sección «Trampas» más abajo).

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

cat <<'EOF' > /tmp/cilium-values.yaml
cni:
  chainingMode: aws-cni
  exclusive: false
enableIPv4Masquerade: false
routingMode: native
nodeSelector:
  work_type: cilium-demo
tolerations:
  - key: dedicated
    operator: Equal
    value: cilium-demo
    effect: NoSchedule
envoy:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
operator:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
  unmanagedPodWatcher:
    restart: false
EOF

helm install cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
```

Los pods `api` y `client` se arrancaron antes de instalar Cilium, así que el CNI chaining
todavía no ha actuado sobre ellos (la documentación de Cilium avisa explícitamente de
esto: los pods existentes deben reiniciarse). Reiniciamos ambos Deployment:

```bash
kubectl rollout restart deployment/api -n eks-132
kubectl rollout restart deployment/client -n eks-132
kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Instalamos el Cilium CLI y comprobamos el estado:

```bash
CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
sudo tar xzvfC "cilium-linux-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-${CLI_ARCH}.tar.gz"

mkdir -p /var/work/tests/artifacts/3
cilium status | tee /var/work/tests/artifacts/3/cilium_status.txt
```

En la salida deben aparecer `Cilium: OK`, `Operator: OK` y `Envoy DaemonSet: OK`, y el
número `Desired` de ambos DaemonSet debe coincidir con el número de nodos `cilium-demo`.

## Tarea 4. Prueba del chaining: las direcciones siguen siendo de VPC CNI

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n eks-132 -o wide > /var/work/tests/artifacts/4/podips.txt
cat /var/work/tests/artifacts/4/podips.txt
```

Las IP de los pods `api` y `client` son del CIDR `10.10.0.0/16` - el mismo rango que la
propia VPC. Si esto fuera un reemplazo completo de VPC CNI con modo overlay, las direcciones
vendrían de un pool virtual separado (`cluster-pool`), no de la subred del nodo. Aquí el
IPAM se quedó en VPC CNI - eso es precisamente el sentido del chaining (chapter 8).

## Tarea 5. Política L7: solo GET

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-l7-allow-get
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/.*"
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-l7-allow-get -n eks-132
```

Comprobamos el GET permitido y el POST bloqueado:

```bash
mkdir -p /var/work/tests/artifacts/5
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_get.txt
cat /var/work/tests/artifacts/5/allowed_get.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 -X POST \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_post.txt || true
cat /var/work/tests/artifacts/5/blocked_post.txt
```

El GET pasa (`HTTP_CODE=200`), el POST es bloqueado por el proxy Envoy de Cilium a nivel L7
(`HTTP_CODE=403`, acceso denegado antes de que la petición llegue siquiera a la
aplicación). La NetworkPolicy integrada de VPC CNI no tiene este filtro por método HTTP -
solo L3/L4 (chapter 8).

Usa el nombre completo `ciliumnetworkpolicies.cilium.io`: el nombre corto `cnp` es ambiguo
en este clúster, porque VPC CNI trae su propio recurso
`clusternetworkpolicies.networking.k8s.aws`, y kubectl avisa de ello.

## Tarea 6. Política FQDN: egress solo a `aws.amazon.com`

Hay dos lugares donde esta política se comporta de forma distinta al ejemplo típico de la
documentación.

Primero: la regla para DNS no se puede escribir mediante `toEndpoints` con la etiqueta
`k8s-app: kube-dns`. `toEndpoints` funciona por identidad de Cilium, y los pods `coredns` de
este clúster viven en Fargate, donde no hay agente de Cilium - no tienen `CiliumEndpoint`,
no entran en el `ipcache` y desde el punto de vista de la política se ven como
`reserved:world`. Una regla por etiqueta nunca coincidiría, el DNS quedaría cerrado por
default-deny, y `curl` ni siquiera podría resolver el nombre. Por eso permitimos el DNS por
CIDR: el rango de servicio del clúster (`172.20.0.0/16`, donde está el ClusterIP
`kube-dns`) y el CIDR de la VPC (`10.10.0.0/16`, donde viven los propios pods `coredns`).
Las reglas L7 `rules.dns` sobre `toCIDRSet` funcionan normalmente - así es exactamente como
Cilium documenta el caso de un servidor DNS externo.

Segundo: el `endpointSelector` sobre `app: client` activa el default-deny para todo el
egress de ese pod. Si dejamos solo `toFQDNs` y DNS, se rompería el GET hacia `api` de la
tarea 5 - sus paquetes se descartarían. Por eso, como tercer bloque, permitimos
explícitamente el egress hacia `api:8080`. Así el estado final del banco queda coherente:
la tarea 5 y la tarea 6 son ciertas al mismo tiempo.

El orden de los bloques importa: `toFQDNs` debe quedar primero (`egress[0]`), el
autotest mira precisamente ahí.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-fqdn-allow-aws
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toFQDNs:
    - matchName: "aws.amazon.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
  - toCIDRSet:
    - cidr: 172.20.0.0/16
    - cidr: 10.10.0.0/16
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
  - toEndpoints:
    - matchLabels:
        app: api
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-fqdn-allow-aws -n eks-132
```

Comprobamos:

```bash
mkdir -p /var/work/tests/artifacts/6
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://aws.amazon.com \
  > /var/work/tests/artifacts/6/allowed_fqdn.txt || true
cat /var/work/tests/artifacts/6/allowed_fqdn.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://example.com \
  > /var/work/tests/artifacts/6/blocked_other_domain.txt || true
cat /var/work/tests/artifacts/6/blocked_other_domain.txt
```

`aws.amazon.com` se resuelve y `curl` pasa - `HTTP_CODE=200`. `example.com` también se
resuelve (el DNS está permitido), pero la sesión TCP hacia su dirección no entra en
`toFQDNs`, los paquetes se descartan, y `curl` se queda colgado hasta `--max-time` -
`HTTP_CODE=000`. La NetworkPolicy integrada de VPC CNI no tiene en absoluto este tipo de
política por nombre DNS - solo `ipBlock` por IP/CIDR (chapter 8).

## Tarea 7. Hubble: observabilidad de flujos con verdict

Activamos Hubble relay encima del Cilium ya instalado, con el mismo `nodeSelector` en
`cilium-demo`:

```bash
cat <<'EOF' >> /tmp/cilium-values.yaml
hubble:
  relay:
    enabled: true
    nodeSelector:
      work_type: cilium-demo
    tolerations:
      - key: dedicated
        operator: Equal
        value: cilium-demo
        effect: NoSchedule
EOF

helm upgrade cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status deployment/hubble-relay --timeout=240s
```

Instalamos el Hubble CLI:

```bash
HUBBLE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz"
```

Levantamos un port-forward al relay (`4245`), repetimos las peticiones bloqueadas de las
tareas 5 y 6 para obtener eventos `DROPPED`, y leemos el flujo:

```bash
setsid nohup kubectl -n kube-system port-forward service/hubble-relay 4245:80 \
  </dev/null >/tmp/pf.log 2>&1 &
sleep 5

CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
for i in 1 2 3; do
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 -X POST \
    http://api.eks-132.svc.cluster.local:8080 >/dev/null 2>&1 || true
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 \
    https://example.com >/dev/null 2>&1 || true
done

mkdir -p /var/work/tests/artifacts/7
hubble observe --server localhost:4245 -n eks-132 --last 200 \
  | tee /var/work/tests/artifacts/7/hubble_denied.txt
grep -c DROPPED /var/work/tests/artifacts/7/hubble_denied.txt
```

Lanza siempre el port-forward mediante `setsid nohup ... </dev/null &`: un
`kubectl port-forward &` normal se cuelga de la sesión SSH y muere si esta se corta.

En el archivo deben aparecer líneas con verdict `DROPPED` - son los SYN descartados hacia
direcciones de `example.com` (`policy-verdict:none ... Policy denied DROPPED`). La
NetworkPolicy integrada de VPC CNI no tiene un mapa de flujos así con verdict por flujo -
allí solo hay logs del agente `aws-network-policy-agent` y métricas (chapter 8).

## Tarea 8. Comparación: VPC CNI NP frente a Cilium en esta lab

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/comparison.txt <<'EOF'
Qué sabe hacer la NetworkPolicy integrada de VPC CNI, qué añadió Cilium, qué se paga por ello:

1. VPC CNI NetworkPolicy solo cubre L3/L4. Cilium en esta lab añadió una regla L7 por
   método HTTP: GET permitido (200), POST rechazado por el proxy Envoy con código 403.

2. VPC CNI NP no tiene políticas por nombre DNS. Cilium añadió una CiliumNetworkPolicy con
   toFQDNs - el egress solo se permite hacia aws.amazon.com, example.com se descarta
   (HTTP_CODE=000).

3. El diagnóstico de la VPC CNI NP integrada son solo logs del agente y métricas. Cilium
   trajo Hubble: un mapa de flujos con verdict por flujo (FORWARDED/DROPPED) mediante
   hubble observe.

4. El precio de esto: tu propio release de Helm de Cilium con sus propias actualizaciones,
   un segundo modelo de CRD para el equipo, una capa adicional en el datapath, y el hecho
   de que los pods fuera del pool cilium-demo (por ejemplo coredns en Fargate) quedan fuera
   del datapath de Cilium y en las políticas solo son visibles como reserved:world - las
   reglas por etiqueta no se les aplican.

5. Un reemplazo completo de VPC CNI (cuando se elimina aws-node y Cilium se convierte en el
   propio IPAM) no entra en el alcance de esta lab: cambiar el CNI en un clúster en vivo es
   una operación blue/green a través de nuevos nodos, no cambiar un flag al vuelo
   (chapter 8, sección 8.8). Aquí solo se practicó la opción segura - CNI chaining.
EOF
cat /var/work/tests/artifacts/8/comparison.txt
```

## Verificación rápida

```bash
check_result
```

## Trampas encontradas en esta lab

Los cuatro puntos se han verificado en un banco en vivo.

1. `cilium-operator` se lleva por delante el DNS del clúster. Por defecto
   `operator.unmanagedPodWatcher.restart=true`: el operador elimina cada 15 segundos los
   pods sin `CiliumEndpoint`. `coredns` en Fargate nunca llegará a serlo, así que sus pods
   se eliminan en bucle, por cada uno nace una nueva micro-VM de Fargate, y el DNS del
   clúster va y viene. El síntoma desde el lado del pod: `nslookup` devuelve
   `connection timed out; no servers could be reached`. Quién exactamente elimina los pods
   se ve en el log de auditoría del control plane: en los registros `verb: delete` sobre
   pods `coredns` aparece `user.username =
   system:serviceaccount:kube-system:cilium-operator` y
   `userAgent = cilium-operator-generic/1.20.0`. Se soluciona con el flag
   `operator.unmanagedPodWatcher.restart=false` (en `cilium-config` aparecerá
   `unmanaged-pod-watcher-interval: "0"`).

2. El perfil de Fargate no entiende `nodeSelector`. Si el perfil cubre todo el namespace
   `kube-system` (`selectors = [{ namespace = "kube-system" }]`), el webhook de Fargate
   marca con su perfil a CUALQUIER pod que añadas a ese namespace más adelante, incluido
   `cilium-operator`. A partir de entonces el pod es programado solo por
   `fargate-scheduler`, que no entiende ni `hostNetwork` ni `nodeSelector` y nunca vuelve al
   scheduler normal. Síntomas: `Pod not supported on Fargate: fields not supported:
   HostNetwork, port contains HostIP or HostPort`, y tras `operator.hostNetwork=false` -
   `MatchNodeSelector failed: Fargate profile kube-system cannot satisfy pod's node
   selector/affinity requirements`. Por eso en esta lab el perfil está restringido con el
   selector de etiqueta `eks.amazonaws.com/component: coredns` (ver
   `eks_fargate_system/terragrunt.hcl`).

3. El perfil de Fargate se ha recreado - reinicia los pods que debería recoger. La mutación
   del pod solo ocurre en el momento de su creación, así que un pod `karpenter` creado
   antes de que el nuevo perfil pasara a `ACTIVE` se quedará para siempre en `Pending` con
   `0/N nodes are available: N node(s) had untolerated taint(s)`. Se soluciona con
   `kubectl delete pod` de ese pod.

4. Los pods `cilium-envoy` se quedan en `Pending` si solo se define el `nodeSelector`
   superior. El DaemonSet `cilium-envoy` tiene su propia sección `envoy.nodeSelector` /
   `envoy.tolerations`; sin ella apunta a todos los nodos Linux, y `cilium status` muestra
   `Envoy DaemonSet: 1 errors`.
