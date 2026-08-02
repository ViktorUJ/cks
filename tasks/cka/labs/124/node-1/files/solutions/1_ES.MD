[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 124 — solución de referencia (HA control plane con 3 nodos)

Se da un clúster con un único control plane `cp1`, inicializado con
`--control-plane-endpoint` y `--upload-certs`, con el CNI instalado. Hay que añadir **dos**
nodos de control plane `cp2` y `cp3` (los prerequisites y los paquetes ya están instalados
en ellos) para obtener un quórum impar de etcd (3 nodos).

Documentación oficial:
[Creating Highly Available clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/),
[kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/).

## Paso 1. Obtener el certificate-key y el comando join (en `cp1`)

```bash
# 1. Subir los certificados del control plane a un secret y obtener el certificate-key
sudo kubeadm init phase upload-certs --upload-certs
# ... imprime: <certificate-key>

# 2. Obtener el comando join básico (token + discovery-hash)
sudo kubeadm token create --print-join-command
# kubeadm join <endpoint>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Compón el comando para un nodo de control plane añadiendo `--control-plane` y
`--certificate-key`.

## Paso 2. Añadir cp2 (tarea 1)

```bash
ssh cp2
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

## Paso 3. Añadir cp3 (tarea 2)

Del mismo modo. Si desde el paso 1 han pasado más de ~2 horas, el `certificate-key` ha
caducado — repite `upload-certs`; si ha caducado el token (~24 h) — vuelve a ejecutar
`kubeadm token create`.

```bash
ssh cp3
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

Comprobación en `cp1`:

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane   # 3 nodos
kubectl get nodes                                            # todos Ready
```

## Paso 4. Comprobar el quórum de etcd (tarea 3)

Con la topología stacked, en cada nodo de control plane se levanta su propio static pod
`etcd-*`:

```bash
kubectl -n kube-system get pods -l component=etcd -o wide
# etcd-cp1   Running
# etcd-cp2   Running
# etcd-cp3   Running

# el número de miembros de etcd directamente (con los certificados, capítulo 37):
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
# 3 líneas — tres miembros del clúster de etcd
```

## Por qué exactamente 3

3 miembros de etcd tienen quórum 2 y sobreviven a la caída de **un** nodo. 2 miembros
sobreviven a **cero** caídas (quórum 2 de 2), lo que es peor que un solo nodo. Por eso la HA
se construye sobre un número impar: 3 (el estándar) o 5 (sobrevive a dos caídas). Un número
par no resulta ventajoso (capítulo 35A).

## Comprobación

```bash
check_result
```
