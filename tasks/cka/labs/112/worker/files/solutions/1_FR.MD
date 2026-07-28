[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 112 — solution de référence (etcd : snapshots et restauration)

Toutes les actions sur etcd se font sur le nœud du control plane
(`ssh k8s1_controlPlane_1`, `sudo -i`). `etcdctl` est déjà installé ; les certificats sont
dans `/etc/kubernetes/pki/etcd/`.

Il est pratique de définir une seule fois les paramètres communs de connexion à etcd :

```bash
# sur le control plane, en root
export ETCDCTL_API=3
export EP="--endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key"
```

## Tâche 1. Prendre le snapshot S1 (état de base) et le copier sur le worker

```bash
# sur le control plane
etcdctl $EP snapshot save /root/etcd-snapshot-1.db
etcdctl snapshot status /root/etcd-snapshot-1.db --write-out=table
```

Copier le snapshot sur la machine de travail (pour la vérification) :

```bash
# depuis worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-1.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-1.db
```

(si `scp` n'arrive pas à prendre le fichier dans `/root`, copiez-le sur le control plane dans
`/tmp` et donnez les droits :
`cp /root/etcd-snapshot-1.db /tmp/ && chmod 644 /tmp/etcd-snapshot-1.db`, puis faites `scp`
depuis `/tmp`.)

## Tâche 2. Apporter des modifications au cluster

Nous créons des « ressources marqueurs » : c'est grâce à elles que nous verrons ensuite la
différence entre les snapshots. Les commandes sont lancées sur la machine de travail (c'est
là que `kubectl` est configuré).

```bash
# sur worker PC
kubectl create namespace snapshot-demo
kubectl -n snapshot-demo create configmap demo-config --from-literal=app=v1
kubectl -n snapshot-demo create deployment demo-web \
  --image=viktoruj/ping_pong --replicas=2

kubectl get ns snapshot-demo
kubectl -n snapshot-demo get cm,deploy
```

## Tâche 3. Prendre le snapshot S2 (après les modifications)

```bash
# sur le control plane
etcdctl $EP snapshot save /root/etcd-snapshot-2.db
etcdctl snapshot status /root/etcd-snapshot-2.db --write-out=table
```

```bash
# depuis worker PC
scp k8s1_controlPlane_1:/root/etcd-snapshot-2.db \
  /var/work/tests/artifacts/etcd/etcd-snapshot-2.db
```

La différence : `etcd-snapshot-1.db` a été pris **avant** la création de `snapshot-demo`, et
`etcd-snapshot-2.db` — **après**. Autrement dit, S2 contient le namespace `snapshot-demo` et
ses ressources, S1 non.

## Tâche 4. Restaurer S1 et vérifier qu'il n'y a pas de ressources en trop

Nous restaurons le tout premier snapshot : le cluster doit revenir à l'état **d'avant** la
création de `snapshot-demo`.

Ordre de la restauration (méthode « arrêter les pods statiques → restaurer dans
`/var/lib/etcd` → relancer les pods statiques ») :

```bash
# sur le control plane, en root
# 1. relever le nom du nœud et les adresses dans le manifeste etcd actuel — utiles pour le restore
grep -E -- '--name=|--initial-cluster=|--initial-advertise-peer-urls=' \
  /etc/kubernetes/manifests/etcd.yaml
# exemple de sortie :
#   - --name=ip-10-10-1-17
#   - --initial-advertise-peer-urls=https://10.10.1.17:2380
#   - --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380

# 2. arrêter tous les pods statiques du control plane (kubelet éteindra leurs conteneurs)
mkdir -p /etc/kubernetes/manifests-stopped
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
# attendre que les conteneurs etcd/apiserver disparaissent
crictl ps

# 3. écarter les données actuelles et restaurer le snapshot S1 dans /var/lib/etcd
mv /var/lib/etcd /var/lib/etcd.bak
etcdctl snapshot restore /root/etcd-snapshot-1.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

# 4. remettre les manifestes — kubelet relèvera le control plane sur les données restaurées
mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

> **Important à propos de `--name` (etcd 3.6+).** Lors du restore, il faut indiquer `--name`,
> `--initial-cluster` et `--initial-advertise-peer-urls` **exactement identiques** à ceux du
> manifeste etcd. Sinon le member restauré ne correspondra pas à celui avec lequel démarre le
> pod statique et etcd tombera avec la panique `member unknown`. Les valeurs viennent de
> l'étape 1.

Nous vérifions que le cluster est remonté et que `snapshot-demo` **a disparu** :

```bash
# depuis worker PC (attendre ~1 minute que l'API remonte)
kubectl get --raw='/healthz'          # ok
kubectl get ns snapshot-demo          # NotFound — pas de ressources en trop
kubectl get pods -n kube-system
```

## Tâche 5. Restaurer le cluster depuis S2

Nous restaurons maintenant le second snapshot : `snapshot-demo` et ses ressources doivent
revenir. La procédure est la même, le snapshot est `/root/etcd-snapshot-2.db`.

```bash
# sur le control plane, en root
mv /etc/kubernetes/manifests/*.yaml /etc/kubernetes/manifests-stopped/
crictl ps                                    # attendre l'arrêt des conteneurs

rm -rf /var/lib/etcd
etcdctl snapshot restore /root/etcd-snapshot-2.db \
  --data-dir=/var/lib/etcd \
  --name=ip-10-10-1-17 \
  --initial-cluster=ip-10-10-1-17=https://10.10.1.17:2380 \
  --initial-advertise-peer-urls=https://10.10.1.17:2380

mv /etc/kubernetes/manifests-stopped/*.yaml /etc/kubernetes/manifests/
```

Nous vérifions que le cluster est sain et que `snapshot-demo` **est revenu** :

```bash
# depuis worker PC
kubectl get --raw='/healthz'                 # ok
kubectl get ns snapshot-demo                 # Active
kubectl -n snapshot-demo get cm,deploy       # demo-config et demo-web sont en place
kubectl get pods -n kube-system
```

Bilan : un snapshot est une image complète de l'état du cluster au moment où il est pris. La
restauration depuis S1 ramène le cluster à l'état « vide », depuis S2 elle rend les
ressources créées.
