[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 111 — solution de référence (mise à niveau du cluster kubeadm)

Le cluster démarre en `1.33.1`. La tâche : mettre à niveau le control plane et le worker vers
`1.33.2`. Ordre : d'abord le control plane, puis le worker ; on met à niveau les nœuds un par
un, en les libérant avec cordon/drain.

Les noms des nœuds sont pris dans `kubectl get nodes` — **ce sont les mêmes noms que nous
utilisons pour `ssh` et pour `drain`/`uncordon`** (dans cet environnement ils se résolvent :
`ssh <nom-du-nœud>` fonctionne) :

```bash
kubectl get nodes
# retenons les noms, par exemple :
CP=ip-10-10-1-151        # control plane (rôle control-plane dans la sortie)
WORKER=ip-10-10-1-81     # worker (rôle <none>)
```

## Étape 1. Control plane

```bash
# on se connecte au nœud du control plane
ssh $CP

# on met kubeadm à niveau vers 1.33.2
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.33.2-1.1
sudo apt-mark hold kubeadm
kubeadm version -o short          # v1.33.2

sudo kubeadm upgrade plan
sudo kubeadm upgrade apply v1.33.2 -y
exit
```

```bash
# depuis la machine de travail, on libère le control plane
kubectl drain $CP --ignore-daemonsets --delete-emptydir-data

# on met à niveau kubelet et kubectl sur le nœud lui-même
ssh $CP '
  sudo apt-mark unhold kubelet kubectl
  sudo apt-get install -y kubelet=1.33.2-1.1 kubectl=1.33.2-1.1
  sudo apt-mark hold kubelet kubectl
  sudo systemctl daemon-reload && sudo systemctl restart kubelet
'

kubectl uncordon $CP
```

## Étape 2. Nœud worker

```bash
# depuis la machine de travail, on libère le worker
kubectl drain $WORKER --ignore-daemonsets --delete-emptydir-data

# sur le nœud worker, on met à niveau kubeadm et la configuration du nœud
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

# depuis la machine de travail, on remet le worker en service
kubectl uncordon $WORKER
```

## Vérification

```bash
kubectl get nodes    # tous les nœuds en v1.33.2, Ready
```

> Remarque : si les paquets `1.33.2-1.1` ne sont pas disponibles, regardez ceux qui le sont :
> `apt-cache madison kubeadm` et utilisez le patch 1.33.x actuel (ajustez alors `TARGET` dans
> la vérification).
