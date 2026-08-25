[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 123 - solución de referencia (Karpenter: NodePool, consolidation, StatefulSet)

Todos los comandos se ejecutan en la máquina worker por SSH. kubectl ya está configurado
para el cluster (el kubeconfig se ensambló vía `aws eks update-kubeconfig` al arrancar la
máquina).

## Tarea 1. Namespace `eks-123`

```bash
kubectl create namespace eks-123
```

## Tarea 2. Inventario de NodePool, EC2NodeClass, NodeClaim

Vemos qué pools ya están configurados en el cluster: el `default` (spot y on-demand) y el
nuevo `stateful` (solo on-demand, taint `dedicated=stateful`):

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== nodepools ==="
  kubectl get nodepools -o wide
  echo "=== ec2nodeclasses ==="
  kubectl get ec2nodeclasses
  echo "=== nodeclaims ==="
  kubectl get nodeclaims
} > /var/work/tests/artifacts/2/inventory.txt

cat /var/work/tests/artifacts/2/inventory.txt
```

La salida debe contener líneas con los nombres `default` y `stateful` - son dos NodePools
independientes, cada uno con su propio `EC2NodeClass` (capítulo 12.2-12.3).

## Tarea 3. StatefulSet `db` en el pool `stateful`

El pool `stateful` está cerrado con el taint `dedicated=stateful:NoSchedule`, así que el
pod necesita una toleration. Los volúmenes no son obligatorios para los fines de esta lab -
el foco está en disruption, no en EBS (el volumen de un StatefulSet con su propio PVC se
trata en el capítulo 23):

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db
  namespace: eks-123
spec:
  serviceName: db
  replicas: 3
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      tolerations:
        - key: dedicated
          operator: Equal
          value: stateful
          effect: NoSchedule
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          resources:
            requests:
              cpu: "250m"
              memory: "128Mi"
EOF

kubectl rollout status statefulset/db -n eks-123
```

Comprobamos que todas las réplicas cayeron en el pool `stateful` (label del node
`work_type=stateful`):

```bash
kubectl get po -n eks-123 -l app=db -o wide
kubectl get nodes -L work_type
```

## Tarea 4. PodDisruptionBudget `db-pdb`

`maxUnavailable: 1` es el principal freno al desalojo voluntario. Karpenter drena a través
de la Eviction API, así que el PDB no permitirá desalojar más de una réplica a la vez:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: db-pdb
  namespace: eks-123
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: db
EOF

kubectl get pdb db-pdb -n eks-123
```

## Tarea 5. Síntoma: un PDB sin derecho a desalojo bloquea la consolidación

Los nodes del pool `stateful` ya están infrautilizados: tres réplicas de `250m` cada una
terminaron repartidas en dos nodes `m6g.medium`, y Karpenter con `consolidateAfter: 30s`
intenta constantemente consolidarlos. No hace falta forzar carga alguna - solo hay que ver
qué es lo que bloquea la consolidación.

Importante: con `maxUnavailable: 1` el PDB NO bloquea la consolidación. Permite un desalojo
a la vez (`ALLOWED DISRUPTIONS=1`), Karpenter drena el node una réplica a la vez y lo
elimina tranquilamente. El bloqueo solo ocurre cuando el PDB no permite ni un solo desalojo.
Endurecemos la protección hasta un bloqueo total - `minAvailable: 3` con tres réplicas:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"maxUnavailable":null,"minAvailable":3}}'

kubectl get pdb db-pdb -n eks-123
```

La columna `ALLOWED DISRUPTIONS` ahora muestra `0`. Después de 1-2 minutos, aparece un
evento de bloqueo en los nodes del pool. Nota: esto NO es `Unconsolidatable`, sino un
`DisruptionBlocked` separado:

```bash
for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $n ==="
  kubectl describe node "$n" | grep -A2 DisruptionBlocked
done
```

Línea esperada: `Pdb prevents pod evictions (PodDisruptionBudget=[eks-123/db-pdb])`. Los
logs del propio controller viven en el namespace `karpenter` (no en `kube-system` - eso
solo tiene addons, Karpenter se despliega como un release separado en el perfil Fargate):

```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i "disrupting node"
```

Guardamos la observación en un artefacto - la salida de `get pdb` más el evento real del
node:

```bash
mkdir -p /var/work/tests/artifacts/5
{
  echo "Sintoma: un PDB que no permite ningun desalojo bloquea la consolidacion."
  echo "db-pdb endurecido a minAvailable=3 con 3 replicas -> ALLOWED DISRUPTIONS=0."
  kubectl get pdb db-pdb -n eks-123
  echo
  echo "=== eventos de los nodes del pool stateful ==="
  for n in $(kubectl get nodes -l work_type=stateful -o jsonpath='{.items[*].metadata.name}'); do
    kubectl describe node "$n" | grep -E "DisruptionBlocked|Unconsolidatable" | sed "s|^|$n |"
  done
} > /var/work/tests/artifacts/5/consolidation.txt

cat /var/work/tests/artifacts/5/consolidation.txt
```

Devolvemos el PDB a un estado funcional, de otro modo la tarea 4 no pasará, y el node del
pool nunca podrá irse:

```bash
kubectl patch pdb db-pdb -n eks-123 --type=merge \
  -p '{"spec":{"minAvailable":null,"maxUnavailable":1}}'

kubectl get pdb db-pdb -n eks-123
```

`ALLOWED DISRUPTIONS` vuelve a ser `1`. Conclusión para la operación: `minAvailable` igual
al número de réplicas (o `maxUnavailable: 0`) detiene no solo la consolidation, sino
cualquier drain - es decir, también las actualizaciones de nodes y el upgrade del cluster
(capítulo 12.6, capítulo 40).

## Tarea 6. Arreglo: un `do-not-disrupt` puntual

La protección correcta de un StatefulSet es la combinación de tres partes (capítulo 12.7),
no una sola anotación sobre todo. El PDB (tarea 4) ya da desalojo por réplica. El
disruption budget del pool `stateful` (`nodes: 50%` en
`eks_karpenter_stateful_vng/terragrunt.hcl`) limita el ritmo, para que Karpenter no toque
todos los nodes del pool a la vez. La tercera parte es `do-not-disrupt`, puntual, solo en la
réplica donde una interrupción es actualmente inaceptable (por ejemplo `db-0` mantiene un
liderazgo o una operación larga), no en todo el StatefulSet:

```bash
kubectl annotate pod db-0 -n eks-123 karpenter.sh/do-not-disrupt=true
kubectl get po db-0 db-1 db-2 -n eks-123 \
  -o custom-columns=NAME:.metadata.name,DO_NOT_DISRUPT:'.metadata.annotations.karpenter\.sh/do-not-disrupt'
```

`db-1` y `db-2` no reciben la anotación - de otro modo la protección se volvería total y
bloquearía no solo la consolidation, sino también el drift (actualizaciones de AMI), como
se describe en el capítulo 12.8.

Que la anotación realmente funciona se ve mediante el mismo mecanismo que el PDB en la
tarea 5 - Karpenter escribe un evento separado en el node que tiene `db-0`:

```bash
NODE=$(kubectl get po db-0 -n eks-123 -o jsonpath='{.spec.nodeName}')
kubectl describe node "$NODE" | grep -A1 'do-not-disrupt'
```

Línea esperada: `DisruptionBlocked ... Pod has "karpenter.sh/do-not-disrupt" annotation
(Pod=eks-123/db-0)`. Es decir, la anotación puntual solo detiene la consolidación del node
que tiene la réplica protegida, mientras que Karpenter puede seguir tocando los demás nodes
del pool.

Guardamos la explicación en un artefacto:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/fix.txt <<'EOF'
La proteccion correcta del StatefulSet db durante la consolidacion son tres partes
independientes, no una sola anotacion total:

1. PDB db-pdb (maxUnavailable: 1) - desalojo por replica, el quorum nunca se pierde. Es
   exactamente este valor el que deja ALLOWED DISRUPTIONS=1. Una proteccion total
   (minAvailable=3 con tres replicas) da ALLOWED DISRUPTIONS=0 y un evento DisruptionBlocked
   "Pdb prevents pod evictions" - para siempre, hasta corregir el propio PDB (tarea 5).
2. El disruption budget del pool stateful (nodes: 50%) - limita cuantos nodes del pool
   puede tocar Karpenter al mismo tiempo, evitando consolidar todo el pool de una vez.
3. karpenter.sh/do-not-disrupt=true puntual en db-0 - protege la replica concreta donde una
   interrupcion es actualmente inaceptable, no todo el StatefulSet.

Si do-not-disrupt estuviera en db-0, db-1 y db-2 al mismo tiempo, esto bloquearia no solo la
consolidation, sino tambien el drift: cuando sale una nueva AMI, los nodes del pool stateful
no podrian actualizarse, y se acumularia una deuda de CVE (capitulo 12.8). Por eso la
anotacion se pone solo en una replica y se retira cuando termina la operacion critica.
EOF

cat /var/work/tests/artifacts/6/fix.txt
```

## Verificación rápida

```bash
check_result
```
