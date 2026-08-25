[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 111 - 參考解答(kubeadm 叢集升級)

叢集的起始版本是 `1.33.1`。任務是把 control plane 與 worker 升級到 `1.33.2`。
順序:先 control plane,再 worker;節點一次升級一個,並透過
cordon/drain 騰空節點。

節點名稱從 `kubectl get nodes` 取得 - **同樣的名稱既用於 `ssh`,也用於
`drain`/`uncordon`**(在這個環境中它們可以解析:`ssh <節點名稱>` 是可用的):

```bash
kubectl get nodes
# 記下名稱,例如:
CP=ip-10-10-1-151        # control plane (輸出中角色為 control-plane)
WORKER=ip-10-10-1-81     # worker (角色為 <none>)
```

## 步驟 1。Control plane

```bash
# 登入 control plane 節點
ssh $CP

# 把 kubeadm 升級到 1.33.2
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
sudo apt-mark hold kubeadm
kubeadm version -o short          # v1.33.2

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.33.2 -y
exit
```

```bash
# 從工作機騰空 control plane
kubectl drain $CP --ignore-daemonsets --delete-emptydir-data

# 在節點本身升級 kubelet 與 kubectl
ssh $CP '
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

kubectl uncordon $CP
```

## 步驟 2。Worker 節點

```bash
# 從工作機騰空 worker
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data

# 在 worker 節點上升級 kubeadm 與節點配置
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

# 從工作機讓 worker 恢復服務
kubectl uncordon $WORKER
```

## 檢查

```bash
kubectl get nodes    # 所有節點都是 v1.33.2,Ready
```

> 注意:如果沒有 `1.33.2-1.1` 這些套件,請查看可用的版本:
> `apt-cache madison kubeadm`,並使用目前可用的 1.33.x 修補版本(此時要調整
> 檢查腳本中的 `TARGET`)。
