[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 116 — solution de référence (installation complète de kubeadm de zéro)

Deux nœuds Ubuntu **vierges** — ni runtime, ni paquets Kubernetes. On installe tout
nous-mêmes : le container runtime (containerd), les paquets `kubeadm/kubelet/kubectl`, on
initialise le control plane, on installe le CNI et on rattache le worker.

- `cp` — control plane (c'est ici qu'on se connecte et qu'on lance `check_result`) ;
- `node` — worker (`ssh node` depuis le nœud `cp`).

Documentation officielle :
[Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/),
[Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/),
[Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

## Étape 0. Prerequisites — sur LES DEUX nœuds (`cp` et `node`)

Exécutez ce bloc sur `cp` et sur `node` (pour `node`, connectez-vous avec `ssh node`).

```bash
# --- swap off ---
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- modules du noyau ---
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# --- sysctl ---
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# --- container runtime : containerd ---
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y containerd.io

# configuration de containerd + SystemdCgroup
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- paquets Kubernetes v1.35 ---
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
```

## Étape 1. Initialisation du control plane (sur `cp`)

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes        # cp NotReady — pas de CNI
```

## Étape 2. Installer le CNI (sur `cp`)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
kubectl get nodes        # cp -> Ready
```

## Étape 3. Rattacher le worker (`node`)

```bash
# sur cp, récupérer la commande join
sudo kubeadm token create --print-join-command

# sur node, l'exécuter en root
ssh node
sudo kubeadm join <cp-private-ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
exit
```

## Étape 4. Vérification (sur `cp`)

```bash
kubectl get nodes        # cp et node à l'état Ready
check_result
```
