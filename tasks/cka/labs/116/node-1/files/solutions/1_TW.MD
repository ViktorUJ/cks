[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 116 - 參考解答(從零開始的完整 kubeadm 安裝)

兩台**乾淨的** Ubuntu 節點 - 既沒有 runtime,也沒有 Kubernetes 套件。我們自己安裝所有東西:
container runtime(containerd)、`kubeadm/kubelet/kubectl` 套件,初始化 control
plane,安裝 CNI 並把 worker 加入叢集。

- `cp` - control plane(我們連到這裡,並在這裡執行 `check_result`);
- `node` - worker(從節點 `cp` 執行 `ssh node`)。

官方文件:
[Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/),
[Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/),
[Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/)。

## 步驟 0。Prerequisites - 在**兩台**節點上(`cp` 與 `node`)

請在 `cp` 和 `node` 上都執行這個區塊(`node` 上請用 `ssh node` 登入)。

```bash
# --- swap off ---
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- 核心模組 ---
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

# containerd 設定檔 + SystemdCgroup
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- Kubernetes v1.35 套件 ---
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

## 步驟 1。初始化 control plane(在 `cp` 上)

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes        # cp NotReady - 還沒有 CNI
```

## 步驟 2。安裝 CNI(在 `cp` 上)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
kubectl get nodes        # cp -> Ready
```

## 步驟 3。加入 worker(`node`)

```bash
# 在 cp 上取得 join 指令
sudo kubeadm token create --print-join-command

# 在 node 上以 root 執行它
ssh node
sudo kubeadm join <cp-private-ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
exit
```

## 步驟 4。驗證(在 `cp` 上)

```bash
kubectl get nodes        # cp 與 node 都是 Ready
check_result
```
