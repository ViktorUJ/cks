[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD)

# Lab 116 — ეტალონური ამოხსნა (kubeadm-ის სრული სეტაპი ნულიდან)

ორი **სუფთა** Ubuntu node — არც რანთაიმი, არც Kubernetes-ის პაკეტები. ყველაფერს თავად
ვაყენებთ: container runtime (containerd), პაკეტები `kubeadm/kubelet/kubectl`, ვაინიციალიზებთ
control plane-ს, ვაყენებთ CNI-ს და ვაერთებთ worker-ს.

- `cp` — control plane (აქ ვუკავშირდებით, აქ ვუშვებთ `check_result`-ს);
- `node` — worker (`ssh node` node `cp`-იდან).

ოფიციალური დოკუმენტაცია:
[Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/),
[Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/),
[Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

## ნაბიჯი 0. Prerequisites — ორივე node-ზე (`cp` და `node`)

შეასრულეთ ეს ბლოკი `cp`-ზეც და `node`-ზეც (`node`-ზე შედით `ssh node`-ით).

```bash
# --- swap off ---
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- ბირთვის მოდულები ---
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

# containerd-ის კონფიგი + SystemdCgroup
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- Kubernetes-ის პაკეტები v1.35 ---
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

## ნაბიჯი 1. control plane-ის ინიციალიზაცია (`cp`-ზე)

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes        # cp NotReady — CNI არ არის
```

## ნაბიჯი 2. CNI-ს დაყენება (`cp`-ზე)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
kubectl get nodes        # cp -> Ready
```

## ნაბიჯი 3. worker-ის მიერთება (`node`)

```bash
# cp-ზე მივიღოთ join-ბრძანება
sudo kubeadm token create --print-join-command

# node-ზე შევასრულოთ იგი root-ით
ssh node
sudo kubeadm join <cp-private-ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
exit
```

## ნაბიჯი 4. შემოწმება (`cp`-ზე)

```bash
kubectl get nodes        # cp და node Ready-ში
check_result
```
