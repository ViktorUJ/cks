[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 118 - solución de referencia (GitOps: Argo CD, drift y self-heal, sync waves)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl ya
está configurado para el clúster (el kubeconfig se genera con `aws eks
update-kubeconfig` al arrancar la máquina).

## Tarea 1. Instalación de Argo CD mediante Helm

```bash
kubectl create namespace argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm install argocd argo/argo-cd -n argocd

kubectl rollout status deployment/argocd-server -n argocd
```

Comprobamos que el servidor se levantó:

```bash
kubectl get deploy argocd-server -n argocd
kubectl get pods -n argocd
```

## Tarea 2. Namespace `eks-118` y el objeto Application

```bash
kubectl create namespace eks-118
```

La Application vincula una fuente en Git (el propio repositorio del curso, rama
`AG-155`, ruta `tasks/eks/labs/118/gitops-demo`) con el clúster de destino y el
namespace `eks-118`. `selfHeal: true` revierte las ediciones manuales, `prune: true`
elimina del clúster los recursos retirados de Git:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/ViktorUJ/cks.git
    targetRevision: AG-155
    path: tasks/eks/labs/118/gitops-demo
  destination:
    server: https://kubernetes.default.svc
    namespace: eks-118
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF
```

Esperamos a que la Application llegue a `Synced` y `Healthy`:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}'
echo
```

Ambos comandos deben devolver finalmente `Synced` y `Healthy` respectivamente (Argo CD
consulta Git y aplica los manifiestos automáticamente, auto-sync está habilitado por
defecto).

## Tarea 3. Comprobación de que los objetos se aplicaron realmente

```bash
kubectl get deployment demo-app -n eks-118
kubectl get configmap demo-config -n eks-118 -o yaml
kubectl rollout status deployment/demo-app -n eks-118
```

El Deployment `demo-app` (imagen `viktoruj/ping_pong:latest`, 2 réplicas) y el ConfigMap
`demo-config` llegaron desde Git a través de Argo CD, no mediante un `kubectl apply`
manual del estudiante.

## Tarea 4. Drift y self-heal

Un detalle importante que solo se ve en un clúster en vivo: con `selfHeal` habilitado,
el controlador revierte el drift en segundos, y es prácticamente imposible ver
`OutOfSync` a simple vista (un `kubectl scale` manual se revierte incluso antes del
primer `kubectl get application`). Por eso el drift se muestra en dos pasos: primero se
desactiva la autocuración, se captura `OutOfSync`, luego se reactiva la autocuración y
se observa la reversión.

Paso 1. Desactivamos solo `selfHeal`, dejamos `prune` habilitado:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":false,"prune":true}}}}'
```

Paso 2. Rompemos el estado en vivo saltándonos Git y capturamos el drift:

```bash
kubectl scale deployment demo-app -n eks-118 --replicas=5

for i in $(seq 1 20); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  [[ "$status" == "OutOfSync" ]] && break
  sleep 3
done

mkdir -p /var/work/tests/artifacts/4
{
  echo "=== drift con selfHeal=false (kubectl scale manual --replicas=5) ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} > /var/work/tests/artifacts/4/drift.txt
```

Sin self-heal, la Application permanece `OutOfSync`: auto-sync reacciona a cambios en
Git, mientras que una diferencia creada dentro del clúster es lo que corrige
precisamente `selfHeal`.

Paso 3. Reactivamos `selfHeal` y observamos la reversión automática al estado de Git:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'

for i in $(seq 1 40); do
  status=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')
  replicas=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.spec.replicas}')
  [[ "$status" == "Synced" ]] && [[ "$replicas" == "2" ]] && break
  sleep 3
done

{
  echo "=== tras reactivar selfHeal: reversión al estado de Git ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  kubectl get deploy demo-app -n eks-118 -o jsonpath='replicas={.spec.replicas}'
  echo
} >> /var/work/tests/artifacts/4/drift.txt

cat /var/work/tests/artifacts/4/drift.txt
```

El archivo contiene tanto `OutOfSync` (drift sin autocuración) como `Synced` (self-heal
devolvió el estado de Git). Al final `replicas` vuelve a ser `2`.

## Tarea 5. Sync waves: orden de aplicación

`gitops-demo/configmap.yaml` lleva la anotación `argocd.argoproj.io/sync-wave: "0"`, y
`gitops-demo/deployment.yaml` lleva `argocd.argoproj.io/sync-wave: "1"`. El número de
ola más bajo se aplica antes, así que el ConfigMap llega garantizado al clúster antes
que el Deployment (esto importa si el Deployment lee valores del ConfigMap mediante
`envFrom`):

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
kubectl get deployment demo-app -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/sync-wave}'
echo
```

Confirmamos que ambos objetos terminan sincronizados a pesar de estar en olas
distintas:

```bash
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application demo-app -n argocd -o jsonpath='{.status.resources}' | head -c 400
```

## Tarea 6. Qué elimina prune y qué no: propiedad de los recursos

`prune: true` ya está habilitado desde la tarea 2. Creamos manualmente en `eks-118` un
ConfigMap que no existe en `gitops-demo/` - un objeto manual normal, como si alguien lo
hubiera creado fuera de Git:

```bash
kubectl create configmap manual-extra -n eks-118 --from-literal=note=manual

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

sleep 30
kubectl get configmap manual-extra -n eks-118
kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}'; echo
```

Resultado inesperado: `prune=true` está habilitado, pero `manual-extra` **no se
elimina**, y la Application sigue `Synced`. La razón está en el modelo de propiedad:
Argo CD solo gestiona los objetos que están marcados como pertenecientes a la
aplicación. En Argo CD 3.x esto es la anotación `argocd.argoproj.io/tracking-id` - mira
cómo está marcado el objeto que llegó desde Git:

```bash
kubectl get configmap demo-config -n eks-118 \
  -o jsonpath='{.metadata.annotations.argocd\.argoproj\.io/tracking-id}'; echo
# demo-app:/ConfigMap:eks-118/demo-config
```

El objeto manual no tiene esa marca, así que para Argo CD es ajeno (orphaned) y no
entra en el alcance de prune. Registramos esta observación:

```bash
mkdir -p /var/work/tests/artifacts/6
{
  echo "=== sin anotacion de tracking, prune no toca el objeto ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "sync: $(kubectl get application demo-app -n argocd -o jsonpath='{.status.sync.status}')"
} > /var/work/tests/artifacts/6/prune.txt
```

Ahora marcamos el ConfigMap como perteneciente a la aplicación. El formato del valor es
`<app>:<group>/<Kind>:<namespace>/<name>`, para recursos del core el group está vacío:

```bash
kubectl annotate configmap manual-extra -n eks-118 \
  'argocd.argoproj.io/tracking-id=demo-app:/ConfigMap:eks-118/manual-extra' --overwrite

kubectl patch application demo-app -n argocd --type=merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

for i in $(seq 1 20); do
  kubectl get configmap manual-extra -n eks-118 >/dev/null 2>&1 || break
  sleep 5
done

kubectl get configmap manual-extra -n eks-118 2>&1
```

Ahora el objeto está rastreado por la aplicación, no está en Git - y prune lo elimina.
Mientras tanto `demo-config` y `demo-app` permanecen en su sitio, porque están
descritos en `gitops-demo/`:

```bash
{
  echo "=== tras anadir la anotacion de tracking, prune elimino el objeto ==="
  echo "manual-extra: $(kubectl get configmap manual-extra -n eks-118 2>&1 | tail -n1)"
  echo "demo-config: $(kubectl get configmap demo-config -n eks-118 -o jsonpath='{.metadata.name}')"
  echo "demo-app: $(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.metadata.name}')"
  echo
  echo "prune solo elimina los recursos RASTREADOS por la aplicacion que faltan en Git."
  echo "Un objeto creado a mano sin anotacion de tracking es ajeno a Argo CD"
  echo "(orphaned) y no entra en prune - ese fue el primer resultado observado."
  echo "demo-config y demo-app permanecieron porque estan descritos en gitops-demo/ y"
  echo "Argo CD sigue sincronizandolos."
} >> /var/work/tests/artifacts/6/prune.txt

cat /var/work/tests/artifacts/6/prune.txt
```

## Tarea 7. Diagnóstico: sync status y health status - dos ejes distintos

Desactivamos auto-sync (y con él self-heal, que vive dentro del mismo bloque), para
poder provocar el síntoma con calma sin una reversión inmediata:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
```

Rompemos el readinessProbe del contenedor directamente en el clúster. Importante: la
imagen de entrenamiento `ping_pong` responde `200` en cualquier ruta, así que una
prueba sobre una "URL inexistente" pasa sin problema y no da síntoma. Dirigimos la
prueba al puerto cerrado `9999` - allí no escucha nadie:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/readinessProbe","value":{
    "httpGet": {"path": "/healthz", "port": 9999},
    "initialDelaySeconds": 2,
    "periodSeconds": 3,
    "failureThreshold": 2
  }}
]'
```

Esperamos y capturamos los estados. Sync y health son ejes independientes: sync
refleja la diferencia entre Git y el estado en vivo, health es la salud real de los
recursos (disponibilidad de los pods, etc.):

```bash
sleep 30
mkdir -p /var/work/tests/artifacts/7
{
  echo "=== estados observados tras la edicion manual del readinessProbe ==="
  kubectl get application demo-app -n argocd \
    -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
  echo
  echo
  echo "=== explicacion: sync status y health status son ejes distintos ==="
  echo "Sync status (Synced/OutOfSync) compara el estado en vivo de los objetos con lo"
  echo "que hay registrado en Git: coincide - Synced, difiere - OutOfSync."
  echo "Health status (Healthy/Progressing/Degraded/Missing) es la salud real del"
  echo "recurso en este momento: si los pods estan listos, si pasaron las pruebas de"
  echo "readiness/liveness."
  echo "Por la prueba en un puerto cerrado, los nuevos pods de demo-app no pasan el"
  echo "readiness, asi que health pasa a Progressing (y se vuelve Degraded tras"
  echo "progressDeadlineSeconds), mientras que sync sigue Synced. La razon: el campo"
  echo "readinessProbe no esta descrito en el manifiesto de Git, y el campo anadido a"
  echo "mano no cuenta en la diferencia; en cambio replicas si esta en Git, por eso su"
  echo "edicion manual en la tarea 4 dio OutOfSync."
  echo "Esto demuestra que ambos ejes se calculan de forma independiente: se puede"
  echo "estar Synced y Degraded/Progressing al mismo tiempo, igual que OutOfSync y"
  echo "Healthy al mismo tiempo."
} > /var/work/tests/artifacts/7/health.txt

cat /var/work/tests/artifacts/7/health.txt
```

Reactivamos auto-sync y self-heal:

```bash
kubectl patch application demo-app -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true}}}}'
```

Observación importante: self-heal **no** corregirá esta rotura. Para Argo CD no hay
diferencia con Git (`sync=Synced`), así que no hay nada que corregir - mientras tanto
`health` muestra honestamente `Progressing`, luego `Degraded`. Conclusión práctica:
`Synced` no significa que el clúster coincida con Git byte a byte; los campos que no
están en el manifiesto siguen siendo responsabilidad del operador. Por eso eliminamos
la prueba a mano:

```bash
kubectl patch deployment demo-app -n eks-118 --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/containers/0/readinessProbe"}]'

for i in $(seq 1 20); do
  health=$(kubectl get application demo-app -n argocd -o jsonpath='{.status.health.status}')
  ready=$(kubectl get deploy demo-app -n eks-118 -o jsonpath='{.status.readyReplicas}')
  [[ "$health" == "Healthy" ]] && [[ "$ready" == "2" ]] && break
  sleep 5
done

kubectl get application demo-app -n argocd \
  -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
echo
```

## Comprobación rápida

```bash
check_result
```
