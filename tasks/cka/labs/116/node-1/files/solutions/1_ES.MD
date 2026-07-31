[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 116 — solución de referencia (setup completo de kubeadm desde cero)

Dos nodos Ubuntu **limpios**: ni runtime ni paquetes de Kubernetes. Instalamos todo
nosotros: el container runtime (containerd), los paquetes `kubeadm/kubelet/kubectl`,
inicializamos el control plane, instalamos el CNI y añadimos el worker.

- `cp` — control plane (aquí nos conectamos, aquí ejecutamos `check_result`);
- `node` — worker (`ssh node` desde el nodo `cp`).

Documentación oficial:
[Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/),
[Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/),
[Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

## Paso 0. Prerequisites — en AMBOS nodos (`cp` y `node`)

Ejecuta este bloque tanto en `cp` como en `node` (en `node` entra con `ssh node`).

```bash
# --- swap off ---
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- módulos del kernel ---
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

# --- container runtime: containerd ---
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y containerd.io

# configuración de containerd + SystemdCgroup
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- paquetes de Kubernetes v1.35 ---
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

## Paso 1. Inicialización del control plane (en `cp`)

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes        # cp NotReady: no hay CNI
```

## Paso 2. Instalar el CNI (en `cp`)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
kubectl get nodes        # cp -> Ready
```

## Paso 3. Añadir el worker (`node`)

```bash
# en cp obtenemos el comando join
sudo kubeadm token create --print-join-command

# en node lo ejecutamos como root
ssh node
sudo kubeadm join <cp-private-ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
exit
```

## Paso 4. Comprobación (en `cp`)

```bash
kubectl get nodes        # cp y node en Ready
check_result
```
