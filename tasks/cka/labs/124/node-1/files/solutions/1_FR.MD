[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 124 — solution de référence (HA control plane à 3 nœuds)

On dispose d'un cluster avec un seul control plane `cp1`, initialisé avec
`--control-plane-endpoint` et `--upload-certs`, avec un CNI installé. Il faut rattacher
**deux** nœuds control plane `cp2` et `cp3` (les prerequisites et les paquets y sont déjà
installés) afin d'obtenir un quorum impair d'etcd (3 nœuds).

Documentation officielle :
[Creating Highly Available clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/),
[kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/).

## Étape 1. Récupérer la certificate-key et la commande join (sur `cp1`)

```bash
# 1. Charger les certificats du control plane dans un secret et récupérer la certificate-key
sudo kubeadm init phase upload-certs --upload-certs
# ... affiche : <certificate-key>

# 2. Récupérer la commande join de base (token + discovery-hash)
sudo kubeadm token create --print-join-command
# kubeadm join <endpoint>:6443 --token ... --discovery-token-ca-cert-hash sha256:...
```

Composez la commande pour un nœud control plane en ajoutant `--control-plane` et
`--certificate-key`.

## Étape 2. Rattacher cp2 (tâche 1)

```bash
ssh cp2
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

## Étape 3. Rattacher cp3 (tâche 2)

De la même manière. Si plus de ~2 heures se sont écoulées depuis l'étape 1, la
`certificate-key` a expiré — refaites `upload-certs` ; si le token a expiré (~24 h) —
relancez `kubeadm token create`.

```bash
ssh cp3
sudo kubeadm join <endpoint>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash> \
  --control-plane \
  --certificate-key <certificate-key>
exit
```

Vérification sur `cp1` :

```bash
kubectl get nodes -l node-role.kubernetes.io/control-plane   # 3 nœuds
kubectl get nodes                                            # tous Ready
```

## Étape 4. Vérifier le quorum etcd (tâche 3)

Avec la topologie stacked, chaque nœud control plane démarre son propre static pod `etcd-*` :

```bash
kubectl -n kube-system get pods -l component=etcd -o wide
# etcd-cp1   Running
# etcd-cp2   Running
# etcd-cp3   Running

# le nombre de membres etcd directement (avec les certificats, chapitre 37) :
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
# 3 lignes — trois membres du cluster etcd
```

## Pourquoi exactement 3

3 membres etcd ont un quorum de 2 et survivent à la perte d'**un** nœud. 2 membres survivent
à **zéro** panne (quorum 2 sur 2) — c'est pire qu'un nœud unique. C'est pourquoi la HA se
construit sur un nombre impair : 3 (le standard) ou 5 (survit à deux pannes). Un nombre pair
n'est pas avantageux (chapitre 35A).

## Vérification

```bash
check_result
```
