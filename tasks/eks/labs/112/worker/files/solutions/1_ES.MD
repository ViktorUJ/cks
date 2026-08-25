[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 112 - solución de referencia (Fargate: perfiles, limitaciones, coste)

Todos los comandos se ejecutan en la máquina de trabajo por SSH. kubectl ya está
configurado para el clúster (el kubeconfig se genera vía `aws eks update-kubeconfig` al
arrancar la máquina). El perfil de Fargate `workload` para el namespace `eks-112` ya está
creado por la infraestructura del laboratorio - el estudiante solo necesita crear el
namespace y los objetos dentro de él.

## Tarea 1. Namespace `eks-112`

```bash
kubectl create namespace eks-112
```

El perfil `workload` coincide por `namespace = eks-112` sin `labels`, así que todo el
namespace entero cae en Fargate - no habrá excepciones dentro de él.

## Tarea 2. Un pod Guaranteed `fg-app` en Fargate

Fargate solo ejecuta pods donde `requests` es igual a `limits` (clase `Guaranteed`).
Creamos un Deployment con valores explícitamente iguales:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
```

Comprobamos que los pods van a un nodo Fargate (el nombre del nodo empieza por `fargate-`,
no por `ip-`):

```bash
kubectl get po -n eks-112 -l app=fg-app -o wide
```

## Tarea 3. Artefacto: la capacidad realmente asignada

Fargate redondea la suma de las peticiones al alza hasta una combinación fija de
vCPU/memoria y añade `256 MB` para los componentes de Kubernetes (`kubelet`, `kube-proxy`,
`containerd`). La capacidad realmente asignada se ve en la anotación `CapacityProvisioned`:

```bash
mkdir -p /var/work/tests/artifacts/3
POD=$(kubectl get po -n eks-112 -l app=fg-app -o jsonpath='{.items[0].metadata.name}')
kubectl get pod "$POD" -n eks-112 \
  -o jsonpath='{.metadata.annotations.CapacityProvisioned}' \
  > /var/work/tests/artifacts/3/capacity.txt
echo >> /var/work/tests/artifacts/3/capacity.txt
cat /var/work/tests/artifacts/3/capacity.txt
```

Para una petición de `500m` de CPU y `1Gi` de memoria más `256 MB` de sobrecarga, Fargate
elegirá la combinación más cercana (por ejemplo `0.5vCPU 1GB`, o `0.5vCPU 2GB` si la memoria
total tras añadir la sobrecarga supera `1 GB`) - `kubectl describe pod` mostrará exactamente
esta línea.

## Tarea 4. Síntoma: un pod privileged no arranca

Fargate prohíbe estrictamente los contenedores privilegiados, los DaemonSet,
hostNetwork/hostPort, hostPath y GPU. Intentamos crear un pod privileged en `eks-112`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: fg-privileged
  namespace: eks-112
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
    securityContext:
      privileged: true
EOF

kubectl get po fg-privileged -n eks-112
kubectl describe po fg-privileged -n eks-112 | sed -n '/Events/,$p'
```

El pod no llega a `Running`: Fargate rechaza los contenedores privilegiados en la fase de
admisión (admission), y esto se ve en los eventos del pod. Guardamos la explicación en el
artefacto:

```bash
mkdir -p /var/work/tests/artifacts/4
cat > /var/work/tests/artifacts/4/privileged.txt <<'EOF'
El Pod fg-privileged no arranca porque pide privileged: true. Fargate no admite
contenedores privilegiados: es una de las limitaciones estrictas de este modo, junto con
DaemonSet, hostNetwork/hostPort, hostPath y GPU. El error se ve en los events del pod como
un rechazo de admission, no como un Pending normal por falta de recursos.
EOF
cat /var/work/tests/artifacts/4/privileged.txt
```

Podemos eliminar el pod para que no interfiera con las siguientes comprobaciones:

```bash
kubectl delete pod fg-privileged -n eks-112
```

## Tarea 5. Ampliación del disco efímero a 30Gi

Por defecto Fargate entrega `20 GiB` de disco efímero, hasta `175 GiB` mediante
`ephemeral-storage` en `resources` (requests debe ser igual a limits, el pod sigue siendo
Guaranteed). Actualizamos `fg-app`:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fg-app
  namespace: eks-112
spec:
  replicas: 2
  selector:
    matchLabels:
      app: fg-app
  template:
    metadata:
      labels:
        app: fg-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
          limits:
            cpu: "500m"
            memory: "1Gi"
            ephemeral-storage: "30Gi"
EOF

kubectl rollout status deployment/fg-app -n eks-112
kubectl get po -n eks-112 -l app=fg-app -o wide
```

El pod arranca con normalidad: `30Gi` está dentro del límite permitido de `175 GiB`, y se
cumple el requisito `requests == limits`.

## Tarea 6. Estructura de coste: Fargate contra node group

La diferencia clave es la unidad de tarificación. Fargate cobra por la vCPU y la memoria de
un pod concreto durante su tiempo de vida; un node group cobra por la instancia EC2 entera
sin importar cuán cargada esté. La verificación automática de este artefacto busca la
palabra `pod` junto a `vCPU`, así que el artefacto de abajo incluye ambas:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/costmodel.txt <<'EOF'
Fargate tarifica la vCPU y la memoria del propio pod durante el tiempo que realmente
se ejecuta: si el pod no está corriendo, no hay coste, y nunca se paga de más por capacidad
ociosa. Un node group, en cambio, tarifica la instancia entera: se paga incluso el tiempo en
que los nodos están ociosos entre pods o infrautilizados. Por unidad de recurso, Fargate
suele ser más caro que el recurso equivalente en un nodo de node group, así que la economía
final depende de la utilización: con carga alta y predecible un node group es más barato,
mientras que con demanda irregular o impredecible Fargate evita pagar de más por instancias
ociosas.
EOF
cat /var/work/tests/artifacts/6/costmodel.txt
```

## Verificación rápida

```bash
check_result
```
