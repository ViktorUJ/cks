[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 117 — solución de referencia (troubleshooting del control plane y de los nodos)

Conexión a los nodos desde la máquina de trabajo:

```bash
ssh k8s1_controlPlane_1     # control plane
ssh k8s1_node_node_1        # worker (el nombre está en /etc/hosts)
```

## Tarea 1. Reparar kube-apiserver (depuración con crictl)

`kubectl` no funciona (`connection refused`): el servidor de la API se ha caído. La única
forma de averiguarlo es depurar al nivel del runtime de contenedores con `crictl`.

```bash
ssh k8s1_controlPlane_1
sudo -i

# ver los contenedores — buscamos kube-apiserver en estado Exited
crictl ps -a | grep kube-apiserver
# CONTAINER   IMAGE   CREATED   STATE    NAME                ATTEMPT
# abc123...   ...     ...       Exited   kube-apiserver      5

# leemos los logs del contenedor caído
crictl logs <container-id>
# Error: unknown flag: --invalid-nonexistent-flag

# corregimos el manifiesto — eliminamos la línea con el flag roto
vi /etc/kubernetes/manifests/kube-apiserver.yaml
# eliminar la línea:    - --invalid-nonexistent-flag=true
```

> **Alternativa:** `grep -n "invalid" /etc/kubernetes/manifests/kube-apiserver.yaml`
> para encontrar la línea y luego `sed -i '/--invalid-nonexistent-flag/d' /etc/kubernetes/manifests/kube-apiserver.yaml`.

kubelet recrea el static pod tras editar el manifiesto. Esperamos ~30 s:

```bash
# en el control plane
crictl ps | grep kube-apiserver    # debe estar Running
exit
```

```bash
# en el worker PC — comprobamos
kubectl get --raw='/healthz'       # ok
```

## Tarea 2. Reparar kube-scheduler

```bash
# síntoma: los pods nuevos no se planifican
kubectl get pod sched-check -n default            # Pending
kubectl -n kube-system get pods -l component=kube-scheduler   # ImagePullBackOff

# vemos la causa
kubectl -n kube-system describe pod -l component=kube-scheduler   # bad image tag v0.0.0-broken

# corregimos el static pod en el nodo control plane
ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/kube-scheduler.yaml
#   image: registry.k8s.io/kube-scheduler:v0.0.0-broken
# ->image: registry.k8s.io/kube-scheduler:v1.35.2   (versión = versión del clúster)
```

kubelet recrea el static pod por sí mismo tras editar el manifiesto.
En ~30-60 s el planificador arranca y `sched-check` pasa a Running.

> La versión exacta de la imagen se puede tomar de un componente que funcione:
> `kubectl -n kube-system get pod -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].image}'`

## Tarea 3. Reparar el nodo worker (NotReady)

```bash
kubectl get nodes                     # el worker está NotReady
kubectl describe node <worker>        # kubelet no reporta su estado

ssh k8s1_node_node_1
sudo systemctl status kubelet         # activating/failed
sudo journalctl -u kubelet -n 10      # failed to load kubelet config file ... NONEXISTENT-config.yaml

# quitamos el drop-in roto (sustituía la ruta del config)
sudo rm /etc/systemd/system/kubelet.service.d/99-broken.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl status kubelet         # active (running)
```

En ~30 s el nodo vuelve a Ready.

## Tarea 4. Reparar el static pod roto en el control plane

```bash
kubectl get pods -n default           # staticweb-<cp> en ImagePullBackOff
kubectl describe pod staticweb-<cp> -n default   # imagen viktoruj/ping_pong:doesnotexist999

ssh k8s1_controlPlane_1
sudo vi /etc/kubernetes/manifests/staticweb.yaml
#   image: viktoruj/ping_pong:doesnotexist999  ->  image: viktoruj/ping_pong:latest
```

kubelet recreará el static pod y el mirror pod `staticweb-<cp>` pasará a Running.

## Verificación

```bash
check_result
```
