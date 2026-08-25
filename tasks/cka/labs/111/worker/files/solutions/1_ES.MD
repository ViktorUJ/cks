[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 — solución de referencia (actualización del clúster kubeadm)

El clúster arranca en `1.33.1`. La tarea es actualizar el control plane y el worker a
`1.33.2`. Orden: primero el control plane, después el worker; los nodos se actualizan uno a
uno, liberándolos con cordon/drain.

Los nombres de los nodos los tomamos de `kubectl get nodes` — **esos mismos nombres se usan
tanto para `ssh` como para `drain`/`uncordon`** (en este entorno se resuelven:
`ssh <nombre-del-nodo>` funciona):

```bash
kubectl get nodes
# anotamos los nombres, por ejemplo:
CP=ip-10-10-1-151        # control plane (rol control-plane en la salida)
WORKER=ip-10-10-1-81     # worker (rol <none>)
```

## Paso 1. Control plane

```bash
# entramos en el nodo del control plane
ssh $CP

# actualizamos kubeadm a 1.33.2
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
sudo apt-mark hold kubeadm
kubeadm version -o short          # v1.33.2

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.33.2 -y
exit
```

```bash
# desde la máquina de trabajo liberamos el control plane
kubectl drain $CP --ignore-daemonsets --delete-emptydir-data

# actualizamos kubelet y kubectl en el propio nodo
ssh $CP '
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

kubectl uncordon $CP
```

## Paso 2. Nodo worker

```bash
# desde la máquina de trabajo liberamos el worker
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data

# en el nodo worker actualizamos kubeadm y la configuración del nodo
ssh $WORKER '
  sudo apt-mark unhold kubeadm
  sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
  sudo apt-mark hold kubeadm
  sudo kubeadm upgrade node
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

# desde la máquina de trabajo devolvemos el worker al servicio
kubectl uncordon $WORKER
```

## Comprobación

```bash
kubectl get nodes    # todos los nodos v1.33.2, Ready
```

> Nota: si no existen los paquetes `1.33.2-1.1`, mira los disponibles con
> `apt-cache madison kubeadm` y usa el parche 1.33.x actual (entonces ajusta `TARGET` en la
> comprobación).
