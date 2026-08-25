[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 111 - 参考解答（kubeadm クラスタの更新）

クラスタはバージョン `1.33.1` から始まります。課題は control plane と worker を `1.33.2` に更新することです。
順序：まず control plane、次に worker；ノードは 1 台ずつ、cordon/drain で
退避させながら更新します。

ノードの名前は `kubectl get nodes` から取得します - **同じ名前を `ssh` にも、
`drain`/`uncordon` にも使います**（この環境では名前解決されます：`ssh <ノード名>` が動きます）：

```bash
kubectl get nodes
# 名前を覚えておきます、例えば:
CP=ip-10-10-1-151        # control plane (出力でのロールは control-plane)
WORKER=ip-10-10-1-81     # worker (ロールは <none>)
```

## ステップ 1。Control plane

```bash
# control plane ノードにログインします
ssh $CP

# kubeadm を 1.33.2 に更新します
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
sudo apt-mark hold kubeadm
kubeadm version -o short          # v1.33.2

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.33.2 -y
exit
```

```bash
# 作業マシンから control plane を退避させます
kubectl drain $CP --ignore-daemonsets --delete-emptydir-data

# ノード自体で kubelet と kubectl を更新します
ssh $CP '
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

kubectl uncordon $CP
```

## ステップ 2。worker ノード

```bash
# 作業マシンから worker を退避させます
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data

# worker ノードで kubeadm とノードの設定を更新します
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

# 作業マシンから worker を稼働に戻します
kubectl uncordon $WORKER
```

## チェック

```bash
kubectl get nodes    # すべてのノードが v1.33.2、Ready
```

> 注意：`1.33.2-1.1` のパッケージが無い場合は、利用可能なものを確認してください：
> `apt-cache madison kubeadm` を使い、現行の 1.33.x のパッチを使ってください（その場合は
> チェック内の `TARGET` を修正します）。
