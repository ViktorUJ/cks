[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 131 - solución de referencia (el PDB bloquea drain, topology spread, matchLabelKeys)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya está
configurado para el cluster (el kubeconfig se generó vía `aws eks update-kubeconfig` al
arrancar la máquina).

## Tarea 1. Namespace `eks-131`

```bash
kubectl create namespace eks-131
```

## Tarea 2. Deployment `web` con topology spread y matchLabelKeys

El cluster del laboratorio corre en dos zonas (`eu-central-1a` y `eu-central-1b`), con
subredes privadas `eks1`/`eks2` para cada una. Esto basta para que Karpenter reparta los
nodos entre dos zonas, y para que `topologySpreadConstraints` reparta los pods entre ellos.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: eks-131
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: web
          matchLabelKeys:
            - pod-template-hash
      containers:
        - name: app
          image: viktoruj/ping_pong:latest
EOF

kubectl rollout status deployment/web -n eks-131
```

Comprobamos la disponibilidad y el reparto entre zonas:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get nodes -L topology.kubernetes.io/zone
```

En la columna `NODE` de los tres pods debe haber al menos dos nodos distintos, y esos nodos
deben tener valores distintos de `topology.kubernetes.io/zone`. `matchLabelKeys:
[pod-template-hash]` todavía no afecta a este primer despliegue (hay una sola revisión) -
se notará en la tarea 6.

## Tarea 3. Síntoma: un PDB demasiado estricto bloquea drain

Creamos un PDB que exige que estén disponibles las 3 réplicas - el presupuesto no permite
retirar ni un pod:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: eks-131
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: web
EOF
```

Tomamos el nodo de una de las réplicas de `web` e intentamos retirarlo:

```bash
NODE=$(kubectl get pod -n eks-131 -l app=web -o jsonpath='{.items[0].spec.nodeName}')
echo "node: $NODE"

mkdir -p /var/work/tests/artifacts/3
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=60s \
  > /var/work/tests/artifacts/3/drain_blocked.txt 2>&1
echo "drain exit code: $?"
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

El comando falla: `kubectl drain` intenta llamar a la API de eviction para el pod `web`,
pero la API responde `429` por violación del presupuesto, y tras `--timeout=60s` drain
termina con error `global timeout reached`. La causa es el PDB `web-pdb` con
`minAvailable: 3`, que exige 3 réplicas disponibles cuando hay exactamente 3, así que el
presupuesto nunca permite retirar ninguna: la expulsión no puede avanzar nunca, drain
quedará colgado hasta que se relaje el presupuesto.

Añadimos la explicación al mismo artefacto:

```bash
cat >> /var/work/tests/artifacts/3/drain_blocked.txt <<'EOF'

Explicación: el PDB web-pdb fija minAvailable: 3, igual al número de réplicas del
Deployment web. El presupuesto no permite retirar ni un pod, así que la API de eviction
responde 429, y kubectl drain se cuelga/agota el timeout - este es el síntoma de un PDB
demasiado estricto, no un error del cluster.
EOF
cat /var/work/tests/artifacts/3/drain_blocked.txt
```

## Tarea 4. Corrección: relajamos el PDB y repetimos drain

Primero devolvemos el nodo a servicio (drain ya lo dejó cordoned):

```bash
kubectl uncordon "$NODE"
```

Relajamos el presupuesto: ahora se puede retirar una réplica de tres (`minAvailable: 2`):

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge -p '{"spec":{"minAvailable":2}}'
kubectl get pdb web-pdb -n eks-131
```

Repetimos drain en el mismo nodo - ahora el presupuesto permite retirar un pod, drain
avanza:

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s \
  > /var/work/tests/artifacts/4/drain_ok.txt 2>&1
echo "drain exit code: $?" >> /var/work/tests/artifacts/4/drain_ok.txt

echo "--- pdb status after drain ---" >> /var/work/tests/artifacts/4/drain_ok.txt
kubectl get pdb web-pdb -n eks-131 >> /var/work/tests/artifacts/4/drain_ok.txt
cat /var/work/tests/artifacts/4/drain_ok.txt
```

Devolvemos el nodo a servicio y esperamos que las 3 réplicas vuelvan a estar listas (el
reemplazo se colocó en otro nodo):

```bash
kubectl uncordon "$NODE"
kubectl rollout status deployment/web -n eks-131
```

## Tarea 5. unhealthyPodEvictionPolicy: AlwaysAllow

Por defecto el PDB usa la política `IfHealthyBudget`: un pod no saludable (no `Ready`) solo
puede expulsarse si el presupuesto no se vería violado de todas formas. Si la aplicación
está rota y un pod queda atascado en `CrashLoopBackOff`, ese pod bloquea por sí mismo el
cálculo del presupuesto y puede impedir drain para siempre. `AlwaysAllow` elimina ese
bloqueo: los pods no saludables siempre pueden expulsarse, los saludables siguen protegidos
por el presupuesto.

```bash
kubectl patch pdb web-pdb -n eks-131 --type merge \
  -p '{"spec":{"unhealthyPodEvictionPolicy":"AlwaysAllow"}}'

kubectl get pdb web-pdb -n eks-131 -o jsonpath='{.spec.unhealthyPodEvictionPolicy}'
echo
```

Guardamos la explicación en el artefacto:

```bash
mkdir -p /var/work/tests/artifacts/5
cat > /var/work/tests/artifacts/5/unhealthy_policy.txt <<'EOF'
unhealthyPodEvictionPolicy: AlwaysAllow añadido a web-pdb.

Por defecto (IfHealthyBudget) un pod no saludable se expulsa solo si currentHealthy no cae
por debajo de desiredHealthy, así que un pod en CrashLoopBackOff se cuenta a sí mismo como
parte del presupuesto y puede bloquear drain para siempre, aunque la aplicación ya no
funcione.

AlwaysAllow permite expulsar un pod no saludable sin importar el presupuesto: un pod roto
en CrashLoopBackOff ya no retiene drain, y las réplicas saludables siguen protegidas por el
PDB.
EOF
cat /var/work/tests/artifacts/5/unhealthy_policy.txt
```

## Tarea 6. Rolling update: matchLabelKeys evita que los pods viejos estorben el reparto

Actualizamos el Deployment para que aparezca una nueva revisión (nuevo
`pod-template-hash`): añadimos una variable de entorno. Los pods viejos y nuevos comparten
la etiqueta `app: web`, pero `matchLabelKeys: [pod-template-hash]` en
`topologySpreadConstraints` hace que el skew se cuente solo dentro de su propia revisión,
así que los pods nuevos no quedan bloqueados por las réplicas viejas.

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl set env deployment/web -n eks-131 RELEASE=v2

kubectl rollout status deployment/web -n eks-131 --timeout=180s \
  | tee /var/work/tests/artifacts/6/rollout.txt
```

Comprobamos que no hay pods `Pending` atascados y que la actualización se aplicó de verdad:

```bash
kubectl get pods -n eks-131 -l app=web -o wide
kubectl get deploy web -n eks-131 \
  -o jsonpath='{.status.readyReplicas}/{.status.updatedReplicas}'
echo
```

Sin `matchLabelKeys: [pod-template-hash]`, tanto los pods viejos como los nuevos contarían
para el skew - comparten la etiqueta `app: web`. Con él, el planificador añade la etiqueta
de revisión al selector y cuenta la distribución solo dentro de su propia revisión.

Una aclaración honesta, que conviene comprobar uno mismo en vez de darla por sentado. En
este entorno el rollout también se completa con éxito sin `matchLabelKeys` - comprobado
por experimento: un segundo Deployment con la misma topología pero sin este campo, con
`maxUnavailable: 0` y `maxSurge: 1`, se actualizó en el mismo tiempo, `Pending` duró menos
de cinco segundos y fue una espera normal del planificador, no un bloqueo por skew. La
razón es simple: tres réplicas en dos zonas dan un reparto de 2 más 1, y el pod adicional
siempre cabe en la zona con menos pods, y si falta sitio en los nodos, Karpenter levanta
otro.

Dónde la diferencia se vuelve real: un parque estático sin capacidad de reserva, más de dos
zonas y una revisión vieja mal repartida. Entonces el skew contado sobre ambas revisiones a
la vez no deja al pod nuevo ninguna zona permitida, y este espera a que se retire una
réplica vieja - en un parque grande esto se convierte en un rollout lento con `Pending`
confusos. Por eso `matchLabelKeys` se configura de antemano, no después de un incidente. El
resultado que realmente se comprueba ahora es que la nueva revisión quedó repartida entre
zonas dentro de `maxSkew: 1`:

```bash
HASH=$(kubectl get po -n eks-131 -l app=web \
  -o jsonpath='{.items[0].metadata.labels.pod-template-hash}')
for n in $(kubectl get po -n eks-131 -l app=web,pod-template-hash="$HASH" \
    -o jsonpath='{.items[*].spec.nodeName}'); do
  kubectl get node "$n" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}{"\n"}'
done | sort | uniq -c
```

## Verificación rápida

```bash
check_result
```
