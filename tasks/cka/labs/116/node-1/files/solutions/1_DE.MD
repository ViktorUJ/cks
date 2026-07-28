[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 116 — Referenzlösung (vollständiges kubeadm-Setup von Null)

Zwei **leere** Ubuntu-Nodes — weder Runtime noch Kubernetes-Pakete. Wir installieren alles
selbst: die Container Runtime (containerd), die Pakete `kubeadm/kubelet/kubectl`,
initialisieren die Control Plane, installieren das CNI und hängen den Worker an.

- `cp` — Control Plane (hier verbinden wir uns, hier starten wir `check_result`);
- `node` — Worker (`ssh node` vom Node `cp`).

Offizielle Dokumentation:
[Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/),
[Container runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/),
[Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).

## Schritt 0. Prerequisites — auf BEIDEN Nodes (`cp` und `node`)

Führe diesen Block sowohl auf `cp` als auch auf `node` aus (auf `node` melde dich mit
`ssh node` an).

```bash
# --- swap off ---
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# --- Kernel-Module ---
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

# --- Container Runtime: containerd ---
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y containerd.io

# containerd-Konfiguration + SystemdCgroup
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# --- Kubernetes-Pakete v1.35 ---
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

## Schritt 1. Initialisierung der Control Plane (auf `cp`)

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl get nodes        # cp NotReady — kein CNI
```

## Schritt 2. CNI installieren (auf `cp`)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
kubectl get nodes        # cp -> Ready
```

## Schritt 3. Worker anhängen (`node`)

```bash
# auf cp den Join-Befehl holen
sudo kubeadm token create --print-join-command

# auf node als root ausführen
ssh node
sudo kubeadm join <cp-private-ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
exit
```

## Schritt 4. Prüfung (auf `cp`)

```bash
kubectl get nodes        # cp und node im Status Ready
check_result
```
