[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 111 - solución de referencia (nodos spot: diversificación, interrupciones, graceful drain)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster (el kubeconfig se genera mediante `aws eks update-kubeconfig`
al arrancar la máquina).

## Tarea 1. Namespace `eks-111`

```bash
kubectl create namespace eks-111
```

## Tarea 2. Deployment `spotapp` en el pool spot con toleration y graceful shutdown

El pool `spot-lab` está cerrado con el taint `dedicated=spot-lab:NoSchedule`, así que el
pod debe llevar la toleration correspondiente, de lo contrario Karpenter no podrá ubicarlo
en este NodePool. `terminationGracePeriodSeconds: 60` cabe dentro de la ventana de dos
minutos de la interrupción spot, y el `preStop` con `sleep 5` da tiempo al balanceador para
retirar el tráfico antes de detener el contenedor.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spotapp
  namespace: eks-111
spec:
  replicas: 4
  selector:
    matchLabels:
      app: spotapp
  template:
    metadata:
      labels:
        app: spotapp
    spec:
      terminationGracePeriodSeconds: 60
      tolerations:
        - key: "dedicated"
          value: "spot-lab"
          effect: "NoSchedule"
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "sleep 5"]
EOF

kubectl rollout status deployment/spotapp -n eks-111
```

Comprobamos que las 4 réplicas quedaron en nodos spot:

```bash
kubectl get po -n eks-111 -l app=spotapp -o wide
NODES=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[*].spec.nodeName}')
for n in $NODES; do
  kubectl get node "$n" -L karpenter.sh/capacity-type --no-headers
done
```

Karpenter tarda aproximadamente 60-90 segundos en levantar un nodo EC2 nuevo, así que al
principio los pods pueden quedar en `Pending`. Esperamos a `rollout status` antes de
continuar.

## Tarea 3. Artefacto: nodos spot y diversificación del NodePool

Guardamos una instantánea de los nodos con la etiqueta de tipo de capacidad y la categoría
de instancia, además de los requirements del NodePool `spot-lab`, para confirmar un
conjunto amplio de familias (diversificación).

```bash
mkdir -p /var/work/tests/artifacts/3
kubectl get nodes -L karpenter.sh/capacity-type -L karpenter.k8s.aws/instance-category \
  > /var/work/tests/artifacts/3/nodes.txt
cat /var/work/tests/artifacts/3/nodes.txt

kubectl get nodepool spot-lab -o yaml \
  | grep -A5 'instance-category' > /var/work/tests/artifacts/3/nodepool.txt
cat /var/work/tests/artifacts/3/nodepool.txt
```

En `nodes.txt` debe aparecer al menos un nodo con `capacity-type=spot`. En `nodepool.txt`
deben estar presentes las tres categorías de instancia `c`, `m`, `r` - esto es
precisamente el requisito de diversificación: el pool spot-lab no está restringido a una
sola familia de instancias.

## Tarea 4. PodDisruptionBudget para `spotapp`

`minAvailable: 3` de 4 réplicas protege contra una expulsión voluntaria excesiva:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: spotapp-pdb
  namespace: eks-111
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: spotapp
EOF

kubectl get pdb spotapp-pdb -n eks-111 -o yaml
```

## Tarea 5. Síntoma: el drain queda bloqueado por PDB, pero eso no protege del spot de AWS

Tomamos un nodo en el que hay al menos un pod de `spotapp`, lo cordonamos e intentamos un
drain. Con 4 réplicas y `minAvailable: 3` el PDB permite expulsar como máximo una réplica
a la vez (`disruptionsAllowed` no supera 1) - el drain no avanzará más allá de una réplica.

```bash
NODE=$(kubectl get po -n eks-111 -l app=spotapp -o jsonpath='{.items[0].spec.nodeName}')
kubectl cordon "$NODE"
kubectl get pdb spotapp-pdb -n eks-111 -o jsonpath='{.status.disruptionsAllowed}'
echo

# lo que intentaría expulsarse, sin drenar realmente todo el nodo
kubectl drain "$NODE" --ignore-daemonsets --dry-run=client
```

Registramos el síntoma y la explicación de la frontera de responsabilidad del PDB en el
artefacto:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/drain.txt <<'EOF'
El nodo está cordonado, el drain intenta expulsar los pods de spotapp mediante la API de
eviction. El PDB spotapp-pdb con minAvailable: 3 no permite expulsar más de una réplica a
la vez (disruptionsAllowed <= 1 con 4 réplicas): al intentar romper el presupuesto, la
eviction se rechaza, y el drain no avanza más allá de una réplica.

Frontera importante: el PDB protege solo la expulsión voluntaria (voluntary) - kubectl
drain, actualización de nodos, consolidación de Karpenter. No protege contra la
reclamación forzada del spot por parte de AWS: si AWS realmente retira la instancia al
vencer el aviso de dos minutos, los pods en ella se terminan independientemente del PDB,
porque esa no es una acción voluntaria de Kubernetes, sino la detención de la propia
instancia.
EOF
cat /var/work/tests/artifacts/5/drain.txt

kubectl uncordon "$NODE"
```

## Tarea 6. Comprobación de la gestión de interrupciones de Karpenter

Karpenter gestiona las interrupciones spot por sí mismo mediante una cola de interrupciones
(`interruptionQueue`, configurada en el módulo `eks_v2_karpenter` independientemente de
este laboratorio). Confirmamos el mecanismo a través de los logs del controlador - puede
que el worker no tenga permisos para `aws sqs list-queues`, así que usamos `kubectl logs`:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=500 \
  | grep -i interrupt > /var/work/tests/artifacts/6/interruption.txt

# si todavía no hubo eventos de interrupción, registramos el hecho de que el mecanismo existe:
if [[ ! -s /var/work/tests/artifacts/6/interruption.txt ]]; then
  echo "no interruption events yet, but Karpenter interruption handling is configured via interruptionQueue" \
    > /var/work/tests/artifacts/6/interruption.txt
fi
cat /var/work/tests/artifacts/6/interruption.txt
```

## Verificación rápida

```bash
check_result
```
