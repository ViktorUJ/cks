[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 113 - Upgrade de un clúster de Kubernetes mediante kubeadm (minor upgrade)

## Objetivo

En este laboratorio de CKS realizarás por tu cuenta un minor-upgrade real de un clúster
autogestionado mediante `kubeadm`: primero el control-plane, luego el nodo worker, en el orden
correcto y sin downtime no planificado de la carga que ya está funcionando. El clúster arranca
en Kubernetes `1.35.x`; tu tarea es llevar ambos nodos a `1.36.x`, respetando el
procedimiento oficial de `kubeadm upgrade` y el cambio del repositorio de paquetes
`pkgs.k8s.io` al nuevo minor.

## Compruébate antes de empezar

<details>
<summary>1. ¿Por qué `kubeadm upgrade` exige hacer el upgrade del control-plane ESTRICTAMENTE antes que el de los nodos worker, y no en cualquier orden?</summary>

`kubeadm upgrade apply` en el control-plane actualiza la versión del API server y de los demás componentes del control-plane; a partir de esa versión se calcula la version skew policy del clúster. Un nodo worker con un kubelet demasiado nuevo respecto del API server puede infringir el skew admitido (el kubelet no debe ser más nuevo que kube-apiserver). Actualizar primero el control-plane garantiza que el API server ya está en la versión objetivo cuando el worker pasa a ella: no es una recomendación arbitraria, sino un requisito de la version skew policy de Kubernetes.
</details>

<details>
<summary>2. ¿Por qué el cambio del repositorio apt `pkgs.k8s.io` es obligatorio al pasar a un nuevo minor, aunque las actualizaciones de patch funcionan sin ello?</summary>

Tras la migración desde `packages.cloud.google.com`/`apt.kubernetes.io`, `pkgs.k8s.io` está organizado como un **repositorio aparte por cada versión minor** (`core:/stable:/v1.35`, `core:/stable:/v1.36`, etc.), y no como un repositorio único con todas las versiones. Dentro del repo `v1.35` ya añadido solo están disponibles las releases de patch `1.35.x`. Para que `apt install kubeadm=1.36.x-*` vea las versiones `1.36`, hay que añadir primero en `sources.list.d/kubernetes.list` precisamente el repo `core:/stable:/v1.36` (cambia solo la versión en la URL; el keyring con la clave de firma `Release.key` se mantiene igual).
</details>

<details>
<summary>3. ¿Por qué `kubectl drain` antes del upgrade del clúster no es simplemente una «buena práctica», sino una protección concreta frente a qué?</summary>

`kubeadm upgrade` en el control-plane recrea los static Pod manifests de los componentes (kube-apiserver, controller-manager, scheduler), y en cualquier nodo el upgrade del kubelet requiere su restart: en ese momento el nodo pierde temporalmente la capacidad de reportar correctamente el estado de los Pods y de aceptar nuevos. `drain` reubica de antemano los workload-Pods normales en otros nodos (o los marca como evicted), para que este fallo temporal del nodo no se convierta en downtime de la aplicación. Sin `drain`, los Pods del nodo que se actualiza pueden quedar no disponibles durante el restart, sin un traslado compensatorio a otro nodo.
</details>

## Relación con el curso

- [Capítulo 13. Actualización de Kubernetes para eliminar vulnerabilidades](../../course/13/es.md)

## Infraestructura

Terragrunt crea un Kubernetes self-managed `1.35.4` en `eu-central-1`, containerd,
Calico CNI:

| Componente | Finalidad |
|---|---|
| `k8s-1` control-plane | un nodo control-plane normal, que admite Pods normales (single control-plane, sin un segundo nodo control-plane dedicado) |
| `k8s-1` worker `worker1` | un nodo worker normal en la misma versión inicial |
| `worker` | máquina de trabajo con `kubectl`, `check_result` y acceso SSH a ambos nodos del clúster |

La versión objetivo del upgrade es `1.36.x` (el último patch disponible en el momento del laboratorio), es decir,
tras completar las tareas el clúster quedará en la misma training baseline que
el resto de los core labs 101-112. Los saltos de versiones minor (por ejemplo, un paso directo `1.35` → `1.37`)
kubeadm no los admite; en este laboratorio tal paso tampoco hace falta.

Para acceder a los nodos usa los alias `k8s113_controlPlane_1` y `k8s113_node_worker1`.

El namespace `upgrade-113` con el Deployment `canary` (2 réplicas) ya está desplegado: es tu
indicador de ausencia de downtime. A lo largo de todo el upgrade al menos una réplica debe
permanecer `Available`; tras el `uncordon` de cada nodo y al final el Deployment debe
recuperarse a `2/2`. El bootstrap distribuye de antemano ambas réplicas en distintos
nodos (required `podAntiAffinity`) y crea un `PodDisruptionBudget` con `minAvailable: 1`.

## Despliegue

```bash
TASK=113 make run_cks_task
```

Conéctate a la máquina de trabajo y elige el contexto ya preparado:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Crea el directorio de evidencias antes de empezar a trabajar:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## Tareas

---
| **1** | **Upgrade del control-plane al minor objetivo** |
| :---: | :--- |
| Qué hacemos | • Entra en `k8s113_controlPlane_1` (`ssh`, luego `sudo -i`).<br/>• Cambia el repositorio apt `pkgs.k8s.io` de `core:/stable:/v1.35` a `core:/stable:/v1.36`: en `/etc/apt/sources.list.d/kubernetes.list` solo cambia la versión en la URL (así lo describe la documentación de Kubernetes, el keyring es el mismo).<br/>• Actualiza el paquete `kubeadm` a `1.36.x`, ejecuta `kubeadm upgrade plan` y luego `kubeadm upgrade apply v1.36.x`.<br/>• Solo después de un `apply` exitoso ejecuta `kubectl drain` de este nodo.<br/>• Actualiza los paquetes `kubelet`/`kubectl` a `1.36.x`, reinicia `kubelet` y luego ejecuta `kubectl uncordon`. |
| Criterios de aceptación | • `kubeadm version`, `kubelet --version`, el `kubectl version --client` local y la versión del API server (`kubectl version`) en el control-plane informan `v1.36.x`.<br/>• El nodo control-plane (`<cp-nombre>` de `kubectl get no`) en estado `Ready`.<br/>• La salida completa del comando `kubeadm upgrade apply` (con la línea `SUCCESS` y la versión objetivo) está guardada literalmente en `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt` en la máquina de trabajo (el comando se ejecuta en el nodo, la salida se escribe en un archivo en el nodo, luego se copia con `scp`). |

<details>
<summary>💡 Pista para la tarea 1</summary>

El orden es esencial: primero `apt-mark unhold kubeadm` → actualizar el paquete → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`, y solo DESPUÉS de un `apply` exitoso, `drain` y la actualización de `kubelet`/`kubectl`. No hace falta actualizar `kubelet` antes de llamar a `kubeadm upgrade apply`, y el procedimiento oficial no lo recomienda. Guarda la salida de `kubeadm upgrade apply` en un archivo en el nodo (`> /tmp/kubeadm-upgrade-apply.txt 2>&1`), y no la reconstruyas de memoria después: el test busca el texto literal con la palabra `SUCCESS`.
</details>

---
| **2** | **Upgrade del nodo worker al minor objetivo** |
| :---: | :--- |
| Qué hacemos | • En `k8s113_node_worker1` (`ssh`, `sudo -i`) cambia igualmente `pkgs.k8s.io` a `core:/stable:/v1.36` y actualiza `kubeadm`.<br/>• Ejecuta `kubeadm upgrade node` (no `apply`: ese comando es solo para el control-plane).<br/>• Ejecuta `kubectl drain` de este nodo (desde la máquina de trabajo, no desde el propio nodo).<br/>• Actualiza `kubelet`/`kubectl`, reinicia `kubelet`, ejecuta `kubectl uncordon`. |
| Criterios de aceptación | • `kubeadm version`, `kubelet --version` y el `kubectl version --client` local en el nodo worker informan `v1.36.x`.<br/>• `kubectl get nodes` muestra para el nodo worker `v1.36.x` en `kubeletVersion` y el estado `Ready`.<br/>• La salida de `kubeadm upgrade node` está guardada en un archivo en el nodo y copiada con `scp` a `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt` en la máquina de trabajo. |

<details>
<summary>💡 Pista para la tarea 2</summary>

`kubeadm upgrade node` es precisamente el comando para los nodos worker (y para los nodos control-plane adicionales), `kubeadm upgrade apply` está destinado solo al PRIMER/único nodo control-plane. Empieza esta tarea solo después de que la tarea 1 esté completamente terminada y el control-plane ya esté `Ready` en `1.36.x`; de lo contrario infringirás la version skew policy.
</details>

---
| **3** | **Respetar el orden correcto del upgrade** |
| :---: | :--- |
| Qué hacemos | • Realiza el upgrade del control-plane (tarea 1) por completo, incluido el uncordon, ANTES de empezar el upgrade del nodo worker (tarea 2).<br/>• Esta tarea no requiere ninguna acción aparte en el clúster: el orden lo comprueba automáticamente el monitor del estado del clúster y de las versiones propiedad del checker. |
| Criterios de aceptación | • El checker-owned monitor registra el baseline inicial `1.35.x`.<br/>• Después se registra el paso completo del control-plane a `1.36.x` (incluidos `Ready` y schedulable) con el worker en `1.35.x`, y solo después de esto el inicio del upgrade del nodo worker.<br/>• El estado sobrevive al reinicio del monitor; la ausencia de baseline o una interrupción de la observación de más de 60 segundos no cuenta. |

<details>
<summary>💡 Pista para la tarea 3</summary>

Si ya empezaste (y más aún si terminaste) el upgrade del nodo worker antes que el del control-plane, detente: revertir el worker a los paquetes `1.35.x` no es posible de forma sencilla, pero el camino correcto es terminar el upgrade del control-plane y luego continuar/repetir el upgrade del nodo worker. Lo principal es que el siguiente upgrade del nodo worker (independientemente de cuándo se inicie) debe producirse después del upgrade completamente terminado del control-plane. No empieces la tarea 2 mientras `kubectl get node <cp-nombre>` no muestre `v1.36.x` y `Ready`.
</details>

---
| **4** | **Demostrar la ausencia de downtime en la carga existente** |
| :---: | :--- |
| Qué hacemos | • Mientras realizas las tareas 1-2, en una sesión aparte en la máquina de trabajo ejecuta un bucle que sondee la disponibilidad del Deployment `canary` en el namespace `upgrade-113` cada pocos segundos.<br/>• Añade cada línea del sondeo a `/var/work/tests/artifacts/4/canary-availability.log` en un formato que contenga `available=N` (por ejemplo `available=2`).<br/>• Continúa el sondeo durante todo el upgrade de ambos nodos. |
| Criterios de aceptación | • El Deployment `canary` al final tiene `2/2` réplicas disponibles, el Deployment/PDB originales y la required Pod anti-affinity se conservan.<br/>• La ausencia de downtime la comprueba el checker-owned monitor por Pod Ready y por los contenedores CRI precisamente de `upgrade-113`; los errores de API/SSH/CRI se cuentan como UNKNOWN, y no como cero.<br/>• El archivo del estudiante `/var/work/tests/artifacts/4/canary-availability.log` contiene como mínimo dos líneas del formato `<unix_timestamp> available=N` o `<unix_timestamp> available=api-unreachable`, con observaciones antes del upgrade del control-plane y después del inicio del upgrade del worker. |

<details>
<summary>💡 Pista para la tarea 4</summary>

Un ejemplo de bucle de sondeo que se puede dejar funcionando en un terminal/`screen`/`tmux` aparte durante toda la ejecución de las tareas 1-2: `while true; do if available=$(kubectl get deployment canary -n upgrade-113 --context "$CTX" -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then echo "$(date +%s) available=${available:-0}"; else echo "$(date +%s) available=api-unreachable"; fi >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`. Si el Deployment perdió todas las réplicas durante un breve tiempo, comprueba `kubectl get pods -n upgrade-113 -o wide` y que los drain sucesivos respetan el PDB y la required anti-affinity.
</details>

## Comprobación

```bash
check_result
```

La comprobación contiene `0 Init` y cinco tests obligatorios. Los tests 1-2 comprueban las versiones de
`kubeadm`/`kubelet`/del `kubectl` local y el estado `Ready` en el control-plane y en el nodo worker
respectivamente, y también el archivo de evidencia literal con la salida de `kubeadm upgrade`. El test 3
comprueba el orden del upgrade por el monitor del estado del clúster propiedad del checker, y no por
la hora de modificación de los archivos. El test 4 comprueba que la carga `canary` no tuvo interrupción,
usando el mismo checker-owned monitor como fuente de verdad. El test 5 es la comprobación
final de que ambos nodos realmente están en la versión objetivo y no se han dejado en estado
`cordon`.

## Solución

Solución de referencia: [worker/files/solutions/1_ES.MD](worker/files/solutions/1_ES.MD).

## Eliminación

```bash
TASK=113 make delete_cks_task
```
