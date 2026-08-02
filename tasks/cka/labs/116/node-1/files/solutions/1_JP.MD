[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 116 - 参考解答（kubeadm のフルセットアップをゼロから）

**まっさらな** Ubuntu ノード 2 台 - ランタイムも Kubernetes のパッケージもありません。すべて自分で導入します：
container runtime（containerd）、`kubeadm/kubelet/kubectl` のパッケージ、control
plane の初期化、CNI のインストール、そして worker の参加です。

- `cp` - control plane（ここに接続し、ここで `check_result` を実行する）；
- `node` - worker（ノード `cp` から `ssh node`）。

公式ドキュメント：
[Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)、
[Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)、
[Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)。

## ステップ 0. Prerequisites - **両方**のノードで（`cp` と `node`）

このブロックを `cp` でも `node` でも実行してください（`node` には `ssh node` で入ります）。

```bash
# --- swap off ---
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- カーネルモジュール ---
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

# containerd の設定 + SystemdCgroup
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- Kubernetes v1.35 のパッケージ ---
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

## ステップ 1. control plane の初期化（`cp` で）

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes        # cp NotReady - CNI がない
```

## ステップ 2. CNI をインストールする（`cp` で）

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
kubectl get nodes        # cp -> Ready
```

## ステップ 3. worker を参加させる（`node`）

```bash
# cp で join コマンドを取得する
sudo kubeadm token create --print-join-command

# node で root として実行する
ssh node
sudo kubeadm join <cp-private-ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
exit
```

## ステップ 4. 確認（`cp` で）

```bash
kubectl get nodes        # cp と node が Ready
check_result
```
