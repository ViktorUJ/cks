[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 110 - solución de referencia (política de red de VPC CNI: default deny, etiqueta, egress)

Todos los comandos se ejecutan en la máquina de trabajo por SSH. kubectl ya está
configurado para el clúster (el kubeconfig se construyó mediante `aws eks
update-kubeconfig` al arrancar la máquina). `enableNetworkPolicy` ya está activado en el
add-on `vpc-cni` mediante Terraform, así que el agente `aws-network-policy-agent` en
`aws-node` está presente en los nodos incluso antes de empezar las tareas.

## Tarea 1. Namespace `eks-110`

```bash
kubectl create namespace eks-110
```

## Tarea 2. Comprobación de que el enforcer está activado

Comprobamos ambos hechos: el contenedor del agente en el DaemonSet `aws-node` y la bandera
de configuración del add-on.

```bash
mkdir -p /var/work/tests/artifacts/2

{
  echo "--- kubectl describe daemonset aws-node ---"
  kubectl describe daemonset aws-node -n kube-system | grep -A2 aws-network-policy-agent
  echo
  echo "--- aws eks describe-addon vpc-cni ---"
  CLUSTER=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' | sed 's|.*/||')
  aws eks describe-addon --cluster-name "$CLUSTER" --addon-name vpc-cni \
    --query "addon.configurationValues" --output text
} > /var/work/tests/artifacts/2/enforcer.txt

cat /var/work/tests/artifacts/2/enforcer.txt
```

La salida debe contener el contenedor `aws-network-policy-agent` en `aws-node` y una línea
como `enableNetworkPolicy":"true"` en la configuración del add-on. Esto confirma que el
control plane y el agente del nodo realmente aplican los objetos `NetworkPolicy`, no solo
los aceptan como un objeto de la API.

## Tarea 3. Síntoma antes de cualquier política: la conectividad está permitida por defecto

Creamos `api` (el servidor) y `client` (para `kubectl exec curl`), además de un Service
para `api`:

```bash
kubectl create deployment api --image=viktoruj/ping_pong:latest --replicas=2 -n eks-110
kubectl rollout status deployment/api -n eks-110

kubectl expose deployment api -n eks-110 --port=8080 --target-port=8080

kubectl create deployment client --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client -n eks-110
```

Comprobamos la conectividad: `client` debería poder alcanzar `api` por el nombre del
Service.

```bash
mkdir -p /var/work/tests/artifacts/3
CLIENT=$(kubectl get po -n eks-110 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/3/connectivity_before.txt

cat /var/work/tests/artifacts/3/connectivity_before.txt
```

El archivo debe contener `HTTP_CODE=200`: sin ninguna política, VPC CNI permite todo el
tráfico este-oeste - todavía no se ha creado ningún objeto `NetworkPolicy` en el clúster.

## Tarea 4. Default deny ingress

Denegamos todo el tráfico entrante hacia el namespace `eks-110`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: eks-110
spec:
  podSelector: {}
  policyTypes: ["Ingress"]
EOF
```

Comprobamos que `client` ya no puede alcanzar `api` (esperando el timeout para no
quedarnos colgados):

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl exec "$CLIENT" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/4/connectivity_denied.txt

cat /var/work/tests/artifacts/4/connectivity_denied.txt
```

El archivo debe mostrar `HTTP_CODE=000` (conexión no establecida) - `podSelector: {}`
significa "todos los pods del namespace", y `policyTypes: ["Ingress"]` sin una sección
`ingress` significa "denegar todo el tráfico entrante". Este es un default deny clásico,
aplicado por el agente `aws-network-policy-agent` mediante eBPF.

## Tarea 5. Permitir por etiqueta: `app: frontend` -> `app: api`

Añadimos una política que permite el tráfico entrante hacia los pods `app: api` solo desde
pods con la etiqueta `app: frontend`, en el puerto `8080`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: ["Ingress"]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
EOF
```

Creamos un cliente con la etiqueta correcta (`frontend`) y otro cliente sin ella
(`client-other`), para poder comparar el resultado:

```bash
kubectl create deployment frontend --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/frontend -n eks-110

kubectl create deployment client-other --image=curlimages/curl:latest -n eks-110 \
  -- sleep 3600
kubectl rollout status deployment/client-other -n eks-110
```

`kubectl create deployment` asigna automáticamente la etiqueta `app: <name>`, así que
`frontend` ya tiene `app: frontend`, mientras que `client-other` obtiene `app:
client-other` (que no coincide con la regla).

Comprobamos ambos casos:

```bash
mkdir -p /var/work/tests/artifacts/5
FRONTEND=$(kubectl get po -n eks-110 -l app=frontend -o jsonpath='{.items[0].metadata.name}')
OTHER=$(kubectl get po -n eks-110 -l app=client-other -o jsonpath='{.items[0].metadata.name}')

kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_frontend.txt

kubectl exec "$OTHER" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_other.txt

cat /var/work/tests/artifacts/5/allowed_frontend.txt
cat /var/work/tests/artifacts/5/blocked_other.txt
```

`allowed_frontend.txt` debe mostrar `HTTP_CODE=200` (la etiqueta coincidió con la regla
`podSelector` en `ingress.from`), mientras que `blocked_other.txt` debe mostrar
`HTTP_CODE=000` (el mismo `default-deny-ingress` de la tarea 4 sigue aplicándose a todo pod
para el que no exista una regla explícita de permiso).

## Tarea 6. Egress con una excepción de DNS

Restringimos el tráfico saliente desde `frontend`: permitimos solo el tráfico hacia los
pods `app: api` y hacia DNS (`kube-system`, puertos `53` UDP/TCP). Todo lo demás (cualquier
dirección externa) queda bloqueado.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: eks-110
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes: ["Egress"]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: api
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
```

Comprobamos que resolver el nombre `api` y acceder a él siguen funcionando (se necesitan
tanto el DNS como el egress permitido hacia el pod `api`):

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://api.eks-110.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/6/egress_dns_api.txt

cat /var/work/tests/artifacts/6/egress_dns_api.txt
```

`HTTP_CODE=200` confirma que la entrada `to.podSelector: app: api` de la política permite
el tráfico hacia `api`, y que la excepción en el puerto `53` en `kube-system` permite a
`frontend` resolver el nombre.

Ahora comprobamos que una dirección externa arbitraria (no cubierta por las reglas
permitidas) queda bloqueada:

```bash
kubectl exec "$FRONTEND" -n eks-110 -- \
  curl -s -o /dev/null -w "HTTP_CODE=%{http_code}\n" --connect-timeout 3 --max-time 5 \
  http://1.1.1.1 \
  > /var/work/tests/artifacts/6/egress_external_blocked.txt

cat /var/work/tests/artifacts/6/egress_external_blocked.txt
```

`HTTP_CODE=000` confirma el deny: `restrict-egress` define la lista completa de destinos
permitidos para `app: frontend`, todo lo demás queda denegado (incluyendo internet y
cualquier otro pod del clúster además de `api`).

## Verificación rápida

```bash
check_result
```
