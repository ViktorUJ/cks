[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 123 — solution de référence (installation du CNI depuis zéro + réseau bas niveau)

Le cluster est démarré **sans CNI** : `kubectl get nodes` → tous les nœuds `NotReady`, les pods
de `netlab` restent en `Pending`/`ContainerCreating`, CoreDNS ne se lance pas. Tant qu'il n'y a
pas de plugin réseau — il n'y a pas de réseau des pods.

Connexion aux nœuds : `ssh k8s1_controlPlane_1`, `ssh k8s1_node_node_1`.

## Tâche 1. Installer le CNI à la main

L'étape officielle de kubeadm est « Installing a Pod network add-on »
([documentation kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#pod-network),
[liste des addons](https://kubernetes.io/docs/concepts/cluster-administration/addons/)).
Nous installons Calico ([Calico quickstart](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)) :

```bash
# prenez une version du manifeste compatible avec k8s 1.35 (voir docs.tigera.io)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml

# on observe le réseau se mettre en place
kubectl -n kube-system get pods -l k8s-app=calico-node -w
kubectl get nodes -w        # les nœuds passent en Ready
```

Après l'installation du CNI :
- les nœuds passent en `Ready` ;
- CoreDNS se lance (`kubectl -n kube-system get deploy coredns`) ;
- les pods `netprobe` de `netlab` se répartissent sur les deux nœuds et passent en `Running`.

> Si vous voulez que le pool d'adresses de Calico corresponde à `--pod-network-cidr=10.0.0.0/16`,
> définissez `CALICO_IPV4POOL_CIDR=10.0.0.0/16` dans le manifeste avant l'`apply` (cela n'a pas
> d'incidence sur la réussite du lab).

## Tâches 2-3 (vérifiées automatiquement)

Dès que le CNI fonctionne, CoreDNS et `netprobe` (2 pods sur des nœuds différents) se lancent
d'eux-mêmes — c'est précisément la confirmation que le réseau des pods fonctionne, y compris
**entre les nœuds**.

## Tâche 4. Rapport sur le réseau bas niveau → `net-lowlevel.txt`

On collecte les informations sur le nœud control plane :

```bash
ssh k8s1_controlPlane_1

# la configuration CNI déposée par le plugin
sudo ls /etc/cni/net.d
# p. ex. : 10-calico.conflist

# le périphérique de la route par défaut
ip route show default
# default via 10.10.1.1 dev ens5 ...   -> dev = ens5
```

Sur la machine de travail :

```bash
mkdir -p /home/ubuntu/answers
cat > /home/ubuntu/answers/net-lowlevel.txt <<EOF
cni_conf=10-calico.conflist
default_route_dev=ens5
EOF
```

> Mettez vos propres valeurs issues des sorties ci-dessus.

## Analyse des network namespaces et des routes (bas niveau)

Il est utile de comprendre comment le CNI relie un pod au réseau du nœud. Sur un nœud qui héberge
un pod :

```bash
# trouver les conteneurs et leurs network namespaces
sudo crictl ps
sudo crictl inspectp <pod-id> | grep -i netns    # chemin du network namespace du pod

# liste des network namespaces
ip netns list
# entrer dans le netns du processus du pod et regarder son réseau
PID=$(sudo crictl inspect <container-id> | jq '.info.pid')
sudo nsenter -t $PID -n ip addr        # l'interface eth0 du pod et son IP
sudo nsenter -t $PID -n ip route       # la route par défaut du pod

# paires veth sur l'hôte (une extrémité dans le pod, l'autre sur le nœud)
ip -o link | grep -E 'cali|veth'
# routes vers les réseaux de pods (Calico ajoute des routes vers les autres nœuds)
ip route | grep -E '10\.|192\.168'
```

L'idée : le CNI crée pour le pod un **network namespace** séparé, le relie à l'hôte par une paire
veth, lui attribue une IP du pool et inscrit des **routes** vers les réseaux de pods des autres
nœuds — c'est ainsi que fonctionne le « réseau plat » de Kubernetes.

Documentation : [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/),
[Network Plugins (CNI)](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/).

## Vérification

```bash
check_result
```
