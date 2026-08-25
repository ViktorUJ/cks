[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 123 — solución de referencia (instalación del CNI desde cero + red de bajo nivel)

El clúster está levantado **sin CNI**: `kubectl get nodes` → todos los nodos en `NotReady`, los
pods de `netlab` están en `Pending`/`ContainerCreating`, CoreDNS no se levanta. Mientras no haya
plugin de red — no hay red de pods.

Conexión a los nodos: `ssh k8s1_controlPlane_1`, `ssh k8s1_node_node_1`.

## Tarea 1. Instalar el CNI a mano

El paso oficial de kubeadm es «Installing a Pod network add-on»
([documentación de kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network),
[lista de addons](https://kubernetes.io/docs/concepts/cluster-administration/addons/)).
Instalamos Calico ([Calico quickstart](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)):

```bash
# elige una versión del manifiesto compatible con k8s 1.35 (ver docs.tigera.io)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

# observamos cómo se levanta la red
kubectl -n kube-system get pods -l k8s-app=calico-node -w
kubectl get nodes -w        # los nodos pasan a Ready
```

Después de instalar el CNI:
- los nodos pasan a `Ready`;
- CoreDNS se levanta (`kubectl -n kube-system get deploy coredns`);
- los pods `netprobe` de `netlab` se reparten en los dos nodos y pasan a `Running`.

> Si quieres que el pool de direcciones de Calico coincida con `--pod-network-cidr=10.0.0.0/16`,
> define `CALICO_IPV4POOL_CIDR=10.0.0.0/16` en el manifiesto antes del `apply` (no influye en
> aprobar el laboratorio).

## Tareas 2-3 (se comprueban automáticamente)

En cuanto el CNI funciona, CoreDNS y `netprobe` (2 pods en nodos distintos) se levantan solos —
eso es precisamente la confirmación de que la red de pods funciona, incluida la **red entre
nodos**.

## Tarea 4. Informe sobre la red de bajo nivel → `net-lowlevel.txt`

Recogemos los datos en el nodo control plane:

```bash
ssh k8s1_controlPlane_1

# el fichero de configuración del CNI que dejó el plugin
sudo ls /etc/cni/net.d
# p. ej.: 10-calico.conflist

# el dispositivo de la ruta por defecto
ip route show default
# default via 10.10.1.1 dev ens5 ...   -> dev = ens5
```

En la máquina de trabajo:

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/net-lowlevel.txt <<EOF
cni_conf=10-calico.conflist
default_route_dev=ens5
EOF
```

> Pon tus propios valores obtenidos de las salidas anteriores.

## Análisis de los network namespaces y las rutas (bajo nivel)

Es útil entender cómo el CNI conecta un pod con la red del nodo. En un nodo donde haya un pod:

```bash
# encontrar los contenedores y sus network namespaces
sudo crictl ps
sudo crictl inspectp <pod-id> | grep -i netns    # ruta al network namespace del pod

# lista de network namespaces
ip netns list
# entrar en el netns del proceso del pod y ver su red
PID=$(sudo crictl inspect <container-id> | jq '.info.pid')
sudo nsenter -t $PID -n ip addr        # la interfaz eth0 del pod y su IP
sudo nsenter -t $PID -n ip route       # la ruta por defecto del pod

# pares veth en el host (un extremo en el pod, el otro en el nodo)
ip -o link | grep -E 'cali|veth'
# rutas hacia las redes de pods (Calico añade rutas a los otros nodos)
ip route | grep -E '10\.|192\.168'
```

La idea: el CNI crea para el pod un **network namespace** aparte, lo une al host con un par veth,
le asigna una IP del pool y escribe **rutas** hacia las redes de pods de los otros nodos — así
funciona la «red plana» de Kubernetes.

Documentación: [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[Network Plugins (CNI)](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/).

## Comprobación

```bash
check_result
```
