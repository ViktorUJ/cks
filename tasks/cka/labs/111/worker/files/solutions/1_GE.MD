[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 — ეტალონური ამოხსნა (kubeadm კლასტერის განახლება)

კლასტერი იწყება `1.33.1`-ზე. ამოცანაა control plane-ისა და worker-ის განახლება
`1.33.2`-მდე. რიგითობა: პირველად control plane, შემდეგ worker; node-ებს ვანახლებთ თითო-თითოდ,
მათ გათავისუფლებით cordon/drain-ის მეშვეობით.

node-ების სახელებს ვიღებთ `kubectl get nodes`-იდან — **იგივე სახელებს ვიყენებთ როგორც
`ssh`-სთვის, ისე `drain`/`uncordon`-ისთვის** (ამ გარემოში ისინი რეზოლვდება:
`ssh <node-ის-სახელი>` მუშაობს):

```bash
kubectl get nodes
# დავიმახსოვროთ სახელები, მაგალითად:
CP=ip-10-10-1-151        # control plane (როლი control-plane გამოტანაში)
WORKER=ip-10-10-1-81     # worker (როლი <none>)
```

## ნაბიჯი 1. Control plane

```bash
# შევდივართ control plane node-ზე
ssh $CP

# ვანახლებთ kubeadm-ს 1.33.2-მდე
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
sudo apt-mark hold kubeadm
kubeadm version -o short          # v1.33.2

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.33.2 -y
exit
```

```bash
# სამუშაო მანქანიდან ვათავისუფლებთ control plane-ს
kubectl drain $CP --ignore-daemonsets --delete-emptydir-data

# ვანახლებთ kubelet-სა და kubectl-ს თავად node-ზე
ssh $CP '
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

kubectl uncordon $CP
```

## ნაბიჯი 2. Worker-node

```bash
# სამუშაო მანქანიდან ვათავისუფლებთ worker-ს
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data

# worker-node-ზე ვანახლებთ kubeadm-სა და node-ის კონფიგურაციას
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

# სამუშაო მანქანიდან ვაბრუნებთ worker-ს მუშაობაში
kubectl uncordon $WORKER
```

## შემოწმება

```bash
kubectl get nodes    # ყველა node v1.33.2, Ready
```

> შენიშვნა: თუ პაკეტები `1.33.2-1.1` არ არის, ნახეთ ხელმისაწვდომები:
> `apt-cache madison kubeadm` და გამოიყენეთ აქტუალური 1.33.x პატჩი (მაშინ შეასწორეთ
> `TARGET` შემოწმებაში).
