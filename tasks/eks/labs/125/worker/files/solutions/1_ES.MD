[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 125 - solución de referencia (EKS Auto Mode frente a tu propio stack)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el clúster. El clúster se creó con Auto Mode activado y un único NodePool
integrado `general-purpose` - no hay perfil de Fargate, addons administrados ni Karpenter
en este lab.

Tomamos el nombre del clúster del kubeconfig: `list-clusters[0]` devolvería el primer
clúster de la cuenta, y no tiene por qué ser el nuestro.

```bash
export CLUSTER=$(kubectl config current-context | awk -F/ '{print $NF}')
echo "$CLUSTER"
```

## Tarea 1. Confirmación del modo: Auto Mode está activado

```bash
mkdir -p /var/work/tests/artifacts/1
{
  echo "=== aws eks describe-cluster computeConfig ==="
  aws eks describe-cluster --name "$CLUSTER" --query 'cluster.computeConfig'
  echo
  echo "=== kubectl get nodepools ==="
  kubectl get nodepools
} > /var/work/tests/artifacts/1/automode.txt
cat /var/work/tests/artifacts/1/automode.txt
```

`computeConfig.enabled` debe ser `true`, y `nodePools` debe contener `general-purpose`.
`kubectl get nodepools` muestra el mismo NodePool como un recurso normal de Kubernetes -
Auto Mode materializa los pools integrados activados a través de la API de Kubernetes
(capítulo 9).

## Tarea 2. El segundo NodePool integrado está desactivado

```bash
kubectl get nodepools
```

`system` no está en la lista - un NodePool integrado aparece como recurso del clúster solo
cuando su nombre está presente en `computeConfig.nodePools`; en este lab ahí solo figura
`general-purpose`.

```bash
mkdir -p /var/work/tests/artifacts/2
cat > /var/work/tests/artifacts/2/twopools.txt <<'EOF'
EKS Auto Mode tiene dos NodePool integrados: general-purpose y system. El NodePool system
lleva el taint CriticalAddonsOnly, tolerado por componentes críticos para el clúster (por
ejemplo CoreDNS) - es una forma de separarlos de la carga normal para que no compitan por
recursos con las aplicaciones ni sean desalojados durante la consolidación de nodos de
general-purpose.

En este lab node_pools contiene solo general-purpose, así que system no se crea como
recurso del clúster: kubectl get nodepools no lo muestra. Activarlo significa editar
computeConfig.nodePools en el control plane, no crear un objeto con kubectl.
EOF
cat /var/work/tests/artifacts/2/twopools.txt
```

## Tarea 3. Carga de trabajo en general-purpose e intento de arreglar el NodePool integrado

```bash
kubectl create namespace eks-125
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=2 -n eks-125
kubectl rollout status deployment/web -n eks-125

kubectl get pods -n eks-125 -o wide
```

Ambas réplicas llegan a `Running` en un nodo que Auto Mode levantó por sí mismo bajo
`general-purpose` - sin perfil de Fargate y sin Karpenter externo, que sí son necesarios en
la base del lab 101.

Intentamos editar el NodePool integrado. AWS documenta los NodePool integrados como
"enabled or disabled but not modified", pero hay que comprobarlo con las manos - no hay
prohibición a nivel de admission:

```bash
mkdir -p /var/work/tests/artifacts/3
{
  echo "=== kubectl patch del pool integrado ==="
  kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":{"cpu":"100"}}}'
  echo "limits tras la edición: $(kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}')"
  echo
  echo "=== quién es dueño del objeto ==="
  kubectl get nodepool general-purpose -o jsonpath='labels={.metadata.labels}{"\n"}'
  kubectl get nodepool general-purpose \
    -o jsonpath='managedFields managers={range .metadata.managedFields[*]}{.manager}{","}{end}{"\n"}'
  echo
  echo "=== conclusión ==="
  echo "La edición se acepta: el comando devolvió patched, el valor quedó en el objeto."
  echo "Pero el objeto pertenece al servicio: etiqueta app.kubernetes.io/managed-by=eks,"
  echo "campos propiedad del manager eks-auto-mode. Solo hay una forma soportada de"
  echo "gestionarlo - activar y desactivar el nombre del pool en computeConfig.nodePools."
  echo "Cambiar esa lista elimina el recurso junto con sus nodos y lo recrea desde cero,"
  echo "sin nuestras ediciones."
} > /var/work/tests/artifacts/3/builtin.txt
cat /var/work/tests/artifacts/3/builtin.txt
```

Devolvemos el pool a su estado original - no necesitamos un `limits` sobrante en un objeto
que no es nuestro:

```bash
kubectl patch nodepool general-purpose --type merge -p '{"spec":{"limits":null}}'
kubectl get nodepool general-purpose -o jsonpath='{.spec.limits}{"\n"}'
```

Atención: `kubectl delete nodepool general-purpose` también se ejecuta, pero EKS NO
recrea el objeto, mientras que los nodos del pool se drenan - el clúster queda sin cómputo.
La recuperación es solo a través de `computeConfig` (receta en la sección "Eliminación"
del README).

## Tarea 4. Sin acceso al nodo: SSH y SSM cerrados por diseño

En Auto Mode el nombre del nodo es el propio instance ID, no hace falta analizar
`providerID` por separado:

```bash
NODE=$(kubectl get pods -n eks-125 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node=$NODE"
```

Reunimos tres pruebas. Primera - la instancia no tiene par de claves (`KeyName`), así que
el SSH por clave es imposible independientemente de si algo escucha en el puerto 22:

```bash
mkdir -p /var/work/tests/artifacts/4
{
  echo "=== par de claves e imagen del nodo ==="
  aws ec2 describe-instances --instance-ids "$NODE" \
    --query 'Reservations[0].Instances[0].[KeyName,ImageId,PlatformDetails]' --output text
  echo "KeyName está vacío (None) - el nodo no tiene par de claves"
  echo
  echo "=== SSM: sin conexión ==="
  aws ssm get-connection-status --target "$NODE" --output json
  echo "inventario de SSM (el nodo no debería estar ahí):"
  aws ssm describe-instance-information \
    --query 'InstanceInformationList[].[InstanceId,PingStatus]' --output text
} > /var/work/tests/artifacts/4/nossh.txt
```

No uses aquí `aws ssm start-session`: la máquina de trabajo no tiene el permiso
`ssm:StartSession`, por lo que el comando devuelve `AccessDeniedException` - eso es un
hecho sobre la política del worker, no sobre el nodo. La respuesta a la pregunta de la
tarea la da `get-connection-status` con estado `notconnected`.

La tercera prueba va en sentido contrario: el host no está aislado del clúster. Un pod
privilegiado con un `hostPath` sobre `/` lee el sistema de archivos del nodo:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: hostprobe
  namespace: eks-125
spec:
  nodeName: $NODE
  restartPolicy: Never
  containers:
  - name: p
    image: busybox
    command: ["sh","-c","cat /host/etc/os-release; echo ---; ls /host/bin | head -5"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: h
      mountPath: /host
  volumes:
  - name: h
    hostPath:
      path: /
EOF

kubectl wait --for=condition=Ready pod/hostprobe -n eks-125 --timeout=90s 2>/dev/null
sleep 5
{
  echo
  echo "=== el host visto desde un pod privilegiado ==="
  kubectl logs hostprobe -n eks-125
  echo
  echo "=== conclusión ==="
  echo "El SSH es imposible (no hay par de claves KeyName), SSM no está conectado"
  echo "(notconnected) - no hay acceso de operador al nodo. Pero la imagen Bottlerocket"
  echo "se puede leer desde un pod privilegiado: Auto Mode cierra la puerta del operador,"
  echo "no la puerta de cluster-admin. De esta última se encargan Pod Security Admission"
  echo "y las políticas de admisión (capítulos 19 y 22)."
} >> /var/work/tests/artifacts/4/nossh.txt

kubectl delete pod hostprobe -n eks-125
cat /var/work/tests/artifacts/4/nossh.txt
```

Los nodos de Auto Mode son Bottlerocket con raíz de solo lectura y SELinux en modo
enforcing, sin shell y sin gestor de paquetes, con una vida máxima de 21 días y reemplazo
automático (capítulo 9). Depurarlos con las herramientas habituales de SSH y SSM es
imposible por principio - ese es el coste de la operación mínima.

## Tarea 5. Tu propio NodePool con limits explícitos

Los pools integrados no tienen `limits` - con una demanda ilimitada crecerían sin techo
(capítulo 9, sección 9.7). Tu propio NodePool referencia el `NodeClass` integrado
`default` y define los límites él mismo:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: custom-limited
spec:
  template:
    spec:
      nodeClassRef:
        group: eks.amazonaws.com
        kind: NodeClass
        name: default
      requirements:
        - key: "eks.amazonaws.com/instance-category"
          operator: In
          values: ["c", "m", "r"]
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
  limits:
    cpu: "10"
    memory: 10Gi
EOF

kubectl get nodepool custom-limited
```

Los NodePool propios no heredan las restricciones de los pools integrados (solo C/M/R,
solo on-demand, generation 5+) - se definen a mano, incluyendo `limits`, o si no el pool
crece sin techo (capítulo 9, sección 9.7).

## Verificación rápida

```bash
check_result
```
