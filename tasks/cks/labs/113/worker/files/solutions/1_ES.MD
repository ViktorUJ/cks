[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 113 - solución de referencia: kubeadm minor upgrade

> Trabajamos como en el examen: `kubectl` en la máquina de trabajo, y las operaciones sobre el nodo (apt, kubeadm,
> kubelet) en el propio nodo: entra en él con `ssh <nodo>`, pasa a root (`sudo -i`),
> ejecuta los comandos y sal (`exit`, `exit`). La versión inicial del clúster es `1.35.x`, la objetivo,
> `1.36.x`. Los nombres de los nodos (`<nombre-cp>`, `<nombre-worker>`) los tomamos de `kubectl get no`; en el examen son otros, en este laboratorio los ssh-alias son: `k8s113_controlPlane_1` y `k8s113_node_worker1`.

## Dónde encontrar los comandos en la documentación

| Qué se necesita | Página y sección |
| :--- | :--- |
| Cambiar el repositorio apt al siguiente minor (se edita solo la versión en la URL del archivo `/etc/apt/sources.list.d/kubernetes.list`, el keyring sigue siendo el mismo) | [Changing the Kubernetes package repository - Switching to another Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/#switching-to-another-kubernetes-package-repository) |
| Elegir la versión (`apt-cache madison kubeadm`) | [Upgrading kubeadm clusters - Determine which version to upgrade to](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#determine-which-version-to-upgrade-to) |
| Actualizar `kubeadm`, `kubeadm upgrade plan`, `kubeadm upgrade apply v1.xx.x` en el primer control-plane | [Upgrading kubeadm clusters - Upgrading control plane nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrading-control-plane-nodes) |
| `kubectl drain <node> --ignore-daemonsets` | [Upgrading kubeadm clusters - Drain the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#drain-the-node) |
| Actualizar `kubelet` y `kubectl`, `systemctl daemon-reload`, `restart kubelet` | [Upgrading kubeadm clusters - Upgrade kubelet and kubectl](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-kubelet-and-kubectl) |
| `kubectl uncordon <node>` | [Upgrading kubeadm clusters - Uncordon the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#uncordon-the-node) |
| Nodo worker: `kubeadm upgrade node` | [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/) |

En los nodos Ubuntu `needrestart` está configurado en modo «solo lista» (sin diálogo OK/Cancel), por lo que
`apt-get install` no se detiene en preguntas.

En lugar de `1.36.x` en los comandos sustituye el patch real de `apt-cache madison kubeadm` y de la
salida de `kubeadm upgrade plan`.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
mkdir -p /var/work/tests/artifacts/{1,2,4}
kubectl get no
```

En `kubectl get no` recuerda los nombres de los nodos (`ip-10-...`): harán falta para `drain` y `uncordon`. Más abajo
`<nombre-cp>` es el nombre del control-plane, `<nombre-worker>` es el nombre del nodo worker.

## Paso 0. En paralelo, lanza el availability-polling (tarea 4)

Antes del upgrade abre una sesión aparte (`tmux`) en la máquina de trabajo y deja el bucle de sondeo del
Deployment `canary` funcionando durante todos los pasos siguientes:

```bash
while true; do
  if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then
    echo "$(date +%s) available=${available:-0}"
  else
    echo "$(date +%s) available=api-unreachable"
  fi >> /var/work/tests/artifacts/4/canary-availability.log
  sleep 5
done
```

## 1. Upgrade del control-plane

```bash
ssh <nombre-cp>
sudo -i
```

```bash
# en el control-plane (root): versiones actuales
kubeadm version -o short; kubelet --version

# cambiar el repositorio al siguiente minor: en el archivo sustituir v1.35 por v1.36
vim /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

apt update
apt-cache madison kubeadm | head -3
```

Actualiza kubeadm (el patch real en lugar de `x`). **Ejecuta este comando por separado:** `apt-get`
vacía el búfer de entrada del terminal, por lo que las líneas pegadas justo detrás se pierden.

```bash
# en el control-plane (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# en el control-plane (root)
kubeadm version -o short
kubeadm upgrade plan
```

Toma la versión concreta de la salida de `plan` y realiza el upgrade, guardando la salida **completa**:

```bash
# en el control-plane (root)
kubeadm upgrade apply v1.36.x -y > /tmp/kubeadm-upgrade-apply.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-apply.txt
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.x".
exit   # de root
exit   # del control-plane
```

```bash
# en la máquina de trabajo: recoger la salida para la comprobación
scp <nombre-cp>:/tmp/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

Solo ahora, DESPUÉS de un `kubeadm upgrade apply` exitoso, el drain del nodo y la actualización de kubelet/kubectl:

```bash
# en la máquina de trabajo
kubectl drain <nombre-cp> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <nombre-cp>
sudo -i
```

```bash
# en el control-plane (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# en el control-plane (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # de root
exit   # del control-plane
```

```bash
# en la máquina de trabajo
kubectl uncordon <nombre-cp>
kubectl get nodes
```

## 2. Upgrade del nodo worker

Empieza solo después de que el control-plane esté `Ready` en `1.36.x` (version skew policy:
el kubelet del nodo worker no puede ser más nuevo que el control-plane). Espera a que `canary` vuelva a estar `2/2`:

```bash
# en la máquina de trabajo: repite hasta que AVAILABLE sea 2
kubectl get deployment canary -n upgrade-113
```

```bash
ssh <nombre-worker>
sudo -i
```

```bash
# en el worker (root): el mismo repositorio que en el control-plane
vim /etc/apt/sources.list.d/kubernetes.list     # v1.35 -> v1.36
apt update
```

```bash
# en el worker (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# en el worker (root)
# en el nodo worker (y en los control-plane adicionales) en lugar de apply se ejecuta upgrade node
kubeadm upgrade node > /tmp/kubeadm-upgrade-node.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-node.txt
exit   # de root
exit   # del worker
```

```bash
# en la máquina de trabajo
scp <nombre-worker>:/tmp/kubeadm-upgrade-node.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
kubectl drain <nombre-worker> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <nombre-worker>
sudo -i
```

```bash
# en el worker (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# en el worker (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # de root
exit   # del worker
```

```bash
# en la máquina de trabajo
kubectl uncordon <nombre-worker>
kubectl get nodes
```

## 3. Comprobación del orden del upgrade

La tarea 3 no requiere comandos aparte: el orden lo demuestra el monitor propiedad del checker
(`/var/lib/cks-lab113-checker/upgrade-monitor.log` en la máquina de trabajo), que se escribía todo el tiempo
desde el bootstrap. Si seguiste los pasos por orden (primero por completo la sección 1, luego la sección 2), en el
log hay una línea en la que el control-plane ya está en `v1.36.x`, `Ready` y schedulable, y el worker todavía en
`v1.35.x`.

## 4. Comprobación de la ausencia de downtime

> Durante `kubeadm upgrade apply` en el único control-plane el API server se reinicia durante unos segundos,
> y `kubectl` en el bucle de sondeo no responde. Esas líneas se anotan como
> `available=api-unreachable` y no entran en el cómputo del mínimo: la indisponibilidad de la API no es una interrupción de
> `canary`. El downtime lo demuestra el monitor independiente del checker (Pod Ready y contenedores mediante `crictl`).

Detén el bucle de sondeo del Paso 0 (`Ctrl+C` en su sesión) y comprueba que el mínimo de `available`
durante la ejecución no bajó a 0:

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | sort -u
kubectl get deployment canary -n upgrade-113
```

Ambas réplicas de `canary` están repartidas en distintos nodos (required `podAntiAffinity`) y protegidas
por un `PodDisruptionBudget` con `minAvailable: 1`, por lo que un drain secuencial correcto (primero
un nodo, luego otro, tras el uncordon) no hace bajar `available` por debajo de `1`.

## Comprobación final

```bash
kubectl get nodes
check_result
```

Ambos nodos deben estar `Ready` en `v1.36.x`, ninguno `SchedulingDisabled`.
