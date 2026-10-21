[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 113 - solution de référence : kubeadm minor upgrade

> Nous travaillons comme à l'examen : `kubectl` - sur la machine de travail, et les opérations sur le nœud (apt, kubeadm,
> kubelet) - sur le nœud lui-même : entrez-y avec `ssh <nœud>`, passez en root (`sudo -i`),
> exécutez les commandes et sortez (`exit`, `exit`). La version de départ du cluster est `1.35.x`, la version cible -
> `1.36.x`. Les noms des nœuds (`<nom-cp>`, `<nom-worker>`) sont pris dans `kubectl get no` ; à l'examen, ils sont différents, dans ce lab les alias ssh sont : `k8s113_controlPlane_1` et `k8s113_node_worker1`.

## Où trouver les commandes dans la documentation

| Ce qu'il faut | Page et section |
| :--- | :--- |
| Basculer le dépôt apt vers le minor suivant (seule la version dans l'URL du fichier `/etc/apt/sources.list.d/kubernetes.list` est modifiée, le keyring reste le même) | [Changing the Kubernetes package repository - Switching to another Kubernetes package repository](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/change-package-repository/#switching-to-another-kubernetes-package-repository) |
| Choisir la version (`apt-cache madison kubeadm`) | [Upgrading kubeadm clusters - Determine which version to upgrade to](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#determine-which-version-to-upgrade-to) |
| Mettre à jour `kubeadm`, `kubeadm upgrade plan`, `kubeadm upgrade apply v1.xx.x` sur le premier control-plane | [Upgrading kubeadm clusters - Upgrading control plane nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrading-control-plane-nodes) |
| `kubectl drain <node> --ignore-daemonsets` | [Upgrading kubeadm clusters - Drain the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#drain-the-node) |
| Mettre à jour `kubelet` et `kubectl`, `systemctl daemon-reload`, `restart kubelet` | [Upgrading kubeadm clusters - Upgrade kubelet and kubectl](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#upgrade-kubelet-and-kubectl) |
| `kubectl uncordon <node>` | [Upgrading kubeadm clusters - Uncordon the node](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/#uncordon-the-node) |
| Nœud worker : `kubeadm upgrade node` | [Upgrading Linux nodes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/upgrading-linux-nodes/) |

Sur les nœuds Ubuntu, `needrestart` est configuré en mode « liste seulement » (sans dialogue OK/Cancel), donc
`apt-get install` ne s'arrête pas sur des questions.

À la place de `1.36.x` dans les commandes, substituez le patch réel issu de `apt-cache madison kubeadm` et de
la sortie de `kubeadm upgrade plan`.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
mkdir -p /var/work/tests/artifacts/{1,2,4}
kubectl get no
```

Dans `kubectl get no`, retenez les noms des nœuds (`ip-10-...`) : ils serviront pour `drain` et `uncordon`. Ci-dessous,
`<nom-cp>` est le nom du control-plane, `<nom-worker>` est le nom du worker.

## Étape 0. Lancez en parallèle le polling de disponibilité (tâche 4)

Avant l'upgrade, ouvrez une session distincte (`tmux`) sur la machine de travail et laissez la boucle d'interrogation du
Deployment `canary` tourner pendant toute la durée des étapes suivantes :

```bash
while true; do
  if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then
    echo "$(date +%s) available=${available:-0}"
  else
    echo "$(date +%s) available=api-unreachable"
  fi >> /var/work/tests/artifacts/4/canary-availability.log
  sleep 5
done
```

## 1. Upgrade du control-plane

```bash
ssh <nom-cp>
sudo -i
```

```bash
# sur le control-plane (root) : versions actuelles
kubeadm version -o short; kubelet --version

# basculer le dépôt vers le minor suivant : dans le fichier, remplacer v1.35 par v1.36
vim /etc/apt/sources.list.d/kubernetes.list
# deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /

apt update
apt-cache madison kubeadm | head -3
```

Mettez à jour kubeadm (le patch réel à la place de `x`). **Exécutez cette commande séparément :** `apt-get`
vide le tampon d'entrée du terminal, donc les lignes collées juste après disparaissent.

```bash
# sur le control-plane (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# sur le control-plane (root)
kubeadm version -o short
kubeadm upgrade plan
```

Prenez la version concrète dans la sortie de `plan` et exécutez l'upgrade en enregistrant la sortie **complète** :

```bash
# sur le control-plane (root)
kubeadm upgrade apply v1.36.x -y > /tmp/kubeadm-upgrade-apply.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-apply.txt
# [upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.36.x".
exit   # de root
exit   # du control-plane
```

```bash
# sur la machine de travail : récupérer la sortie pour la vérification
scp <nom-cp>:/tmp/kubeadm-upgrade-apply.txt /var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt
```

Seulement maintenant, APRÈS un `kubeadm upgrade apply` réussi, drain du nœud et mise à jour de kubelet/kubectl :

```bash
# sur la machine de travail
kubectl drain <nom-cp> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <nom-cp>
sudo -i
```

```bash
# sur le control-plane (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# sur le control-plane (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # de root
exit   # du control-plane
```

```bash
# sur la machine de travail
kubectl uncordon <nom-cp>
kubectl get nodes
```

## 2. Upgrade du worker

Ne commencez qu'après que le control-plane est `Ready` en `1.36.x` (version skew policy :
le kubelet du worker ne peut pas être plus récent que le control-plane). Attendez que `canary` soit de nouveau `2/2` :

```bash
# sur la machine de travail : répétez jusqu'à ce que AVAILABLE devienne 2
kubectl get deployment canary -n upgrade-113
```

```bash
ssh <nom-worker>
sudo -i
```

```bash
# sur le worker (root) : le même dépôt que sur le control-plane
vim /etc/apt/sources.list.d/kubernetes.list     # v1.35 -> v1.36
apt update
```

```bash
# sur le worker (root)
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm='1.36.x-*' && apt-mark hold kubeadm
```

```bash
# sur le worker (root)
# sur le worker (et les control-plane supplémentaires), on exécute upgrade node à la place de apply
kubeadm upgrade node > /tmp/kubeadm-upgrade-node.txt 2>&1
tail -3 /tmp/kubeadm-upgrade-node.txt
exit   # de root
exit   # du worker
```

```bash
# sur la machine de travail
scp <nom-worker>:/tmp/kubeadm-upgrade-node.txt /var/work/tests/artifacts/2/kubeadm-upgrade-node.txt
kubectl drain <nom-worker> --ignore-daemonsets --delete-emptydir-data
```

```bash
ssh <nom-worker>
sudo -i
```

```bash
# sur le worker (root)
apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet='1.36.x-*' kubectl='1.36.x-*' && apt-mark hold kubelet kubectl
```

```bash
# sur le worker (root)
systemctl daemon-reload
systemctl restart kubelet
kubelet --version
exit   # de root
exit   # du worker
```

```bash
# sur la machine de travail
kubectl uncordon <nom-worker>
kubectl get nodes
```

## 3. Vérification de l'ordre de l'upgrade

La tâche 3 n'exige pas de commandes distinctes : l'ordre est démontré par le checker-owned monitor
(`/var/lib/cks-lab113-checker/upgrade-monitor.log` sur la machine de travail), qui était écrit en continu
depuis le bootstrap. Si vous avez suivi les étapes dans l'ordre (d'abord entièrement la section 1, puis la section 2), dans
le log il y a une ligne où le control-plane est déjà en `v1.36.x`, `Ready` et schedulable, tandis que le worker est encore en
`v1.35.x`.

## 4. Vérification de l'absence de downtime

> Pendant `kubeadm upgrade apply` sur l'unique control-plane, l'API server redémarre quelques secondes,
> et `kubectl` dans la boucle d'interrogation ne répond pas. Ces lignes sont enregistrées comme
> `available=api-unreachable` et n'entrent pas dans le calcul du minimum : l'indisponibilité de l'API n'est pas une interruption de
> `canary`. Le downtime est démontré par le moniteur indépendant du checker (Pod Ready et conteneurs via `crictl`).

Arrêtez la boucle d'interrogation de l'Étape 0 (`Ctrl+C` dans sa session) et vérifiez que le minimum de `available`
sur l'exécution n'est pas descendu à 0 :

```bash
grep -oE 'available=[0-9]+' /var/work/tests/artifacts/4/canary-availability.log | sort -u
kubectl get deployment canary -n upgrade-113
```

Les deux répliques de `canary` sont réparties sur des nœuds différents (required `podAntiAffinity`) et protégées par
un `PodDisruptionBudget` avec `minAvailable: 1`, donc un drain séquentiel correct (d'abord
un nœud, puis l'autre, après l'uncordon) ne fait pas descendre `available` en dessous de `1`.

## Vérification finale

```bash
kubectl get nodes
check_result
```

Les deux nœuds doivent être `Ready` en `v1.36.x`, aucun ne doit être `SchedulingDisabled`.
