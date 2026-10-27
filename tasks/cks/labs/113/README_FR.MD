[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 113 - Upgrade d'un cluster Kubernetes via kubeadm (minor upgrade)

## Objectif

Dans ce lab CKS, vous allez réaliser vous-même un véritable minor-upgrade d'un cluster
auto-géré via `kubeadm` : d'abord le control-plane, puis le worker, dans le bon
ordre et sans downtime non planifié de la charge déjà en fonctionnement. Le cluster démarre
sur Kubernetes `1.35.x` ; votre tâche consiste à faire passer les deux nœuds en `1.36.x`, en respectant
la procédure officielle `kubeadm upgrade` et le basculement du dépôt de paquets
`pkgs.k8s.io` vers le nouveau minor.

## Vérifiez-vous avant de commencer

<details>
<summary>1. Pourquoi `kubeadm upgrade` exige-t-il d'upgrader le control-plane STRICTEMENT avant les workers, et non dans n'importe quel ordre ?</summary>

`kubeadm upgrade apply` sur le control-plane met à jour la version de l'API server et des autres composants du control-plane ; c'est à partir de cette version que se calcule la version skew policy du cluster. Un nœud worker avec un kubelet trop récent par rapport à l'API server peut enfreindre le skew pris en charge (le kubelet ne doit pas être plus récent que kube-apiserver). Mettre à jour le control-plane en premier garantit que l'API server est déjà à la version cible lorsque le worker passe à cette même version - ce n'est pas une recommandation arbitraire, mais une exigence de la version skew policy de Kubernetes.
</details>

<details>
<summary>2. Pourquoi le basculement du dépôt apt `pkgs.k8s.io` est-il obligatoire lors du passage à un nouveau minor, alors que les mises à jour de patch fonctionnent sans lui ?</summary>

Depuis la migration à partir de `packages.cloud.google.com`/`apt.kubernetes.io`, `pkgs.k8s.io` est organisé comme un **dépôt distinct pour chaque version minor** (`core:/stable:/v1.35`, `core:/stable:/v1.36`, etc.), et non comme un dépôt unique avec toutes les versions. Dans le repo `v1.35` déjà connecté, seules les releases de patch `1.35.x` sont disponibles. Pour que `apt install kubeadm=1.36.x-*` voie les versions `1.36`, il faut d'abord ajouter dans `sources.list.d/kubernetes.list` précisément le repo `core:/stable:/v1.36` (seule la version change dans l'URL ; le keyring avec la clé de signature `Release.key` reste le même).
</details>

<details>
<summary>3. Pourquoi `kubectl drain` avant l'upgrade du cluster n'est-il pas simplement une « bonne pratique », mais une protection concrète contre quoi ?</summary>

`kubeadm upgrade` sur le control-plane recrée les manifests de static Pod des composants (kube-apiserver, controller-manager, scheduler), et sur n'importe quel nœud, l'upgrade du kubelet exige son restart - à ce moment, le nœud perd temporairement la capacité de rapporter correctement l'état des Pods et d'en accepter de nouveaux. `drain` déplace à l'avance les Pods de workload ordinaires vers d'autres nœuds (ou les marque comme evicted), afin que cette défaillance temporaire du nœud ne se transforme pas en downtime de l'application. Sans `drain`, les Pods du nœud en cours de mise à jour peuvent devenir indisponibles pendant le restart, sans déplacement compensatoire vers un autre nœud.
</details>

## Lien avec le cours

- [Chapitre 13. Mise à jour de Kubernetes pour corriger les vulnérabilités](../../course/13/fr.md)

## Infrastructure

Terragrunt crée un Kubernetes self-managed `1.35.4` dans `eu-central-1`, avec containerd et
Calico CNI :

| Composant | Rôle |
|---|---|
| `k8s-1` control-plane | nœud control-plane ordinaire, admettant des Pods ordinaires (single control-plane, sans second nœud control-plane dédié) |
| `k8s-1` worker `worker1` | nœud worker ordinaire sur la même version de départ |
| `worker` | machine de travail avec `kubectl`, `check_result` et un accès SSH aux deux nœuds du cluster |

La version cible de l'upgrade est `1.36.x` (le dernier patch disponible au moment du lab), c'est-à-dire
qu'après l'exécution des tâches, le cluster se retrouvera sur la même training baseline que
les autres core labs 101-112. Le saut de versions minor (par exemple le passage direct `1.35` → `1.37`)
n'est pas pris en charge par kubeadm - dans ce lab, un tel passage n'est d'ailleurs pas nécessaire.

Pour accéder aux nœuds, utilisez les alias `k8s113_controlPlane_1` et `k8s113_node_worker1`.

Le namespace `upgrade-113` avec le Deployment `canary` (2 répliques) est déjà déployé - c'est votre
indicateur d'absence de downtime. Pendant toute la durée de l'upgrade, au moins une réplique doit
rester `Available` ; après l'`uncordon` de chaque nœud et à la fin, le Deployment doit
revenir à `2/2`. Le bootstrap répartit à l'avance les deux répliques sur des
nœuds différents (required `podAntiAffinity`) et crée un `PodDisruptionBudget` avec `minAvailable: 1`.

## Déploiement

```bash
TASK=113 make run_cks_task
```

Connectez-vous à la machine de travail et choisissez le contexte prêt à l'emploi :

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Créez le répertoire des preuves avant de commencer le travail :

```bash
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## Tâches

---
| **1** | **Upgrade du control-plane vers le minor cible** |
| :---: | :--- |
| Ce qu'on fait | • Connectez-vous à `k8s113_controlPlane_1` (`ssh`, puis `sudo -i`).<br/>• Basculez le dépôt apt `pkgs.k8s.io` de `core:/stable:/v1.35` vers `core:/stable:/v1.36` : dans `/etc/apt/sources.list.d/kubernetes.list`, seule la version dans l'URL change (c'est ainsi que le décrit la documentation Kubernetes, le keyring reste le même).<br/>• Mettez à jour le paquet `kubeadm` vers `1.36.x`, exécutez `kubeadm upgrade plan`, puis `kubeadm upgrade apply v1.36.x`.<br/>• Seulement après un `apply` réussi, exécutez `kubectl drain` sur ce nœud.<br/>• Mettez à jour les paquets `kubelet`/`kubectl` vers `1.36.x`, redémarrez `kubelet`, puis exécutez `kubectl uncordon`. |
| Critères d'acceptation | • `kubeadm version`, `kubelet --version`, le `kubectl version --client` local et la version de l'API server (`kubectl version`) sur le control-plane indiquent `v1.36.x`.<br/>• Le nœud control-plane (`<nom-cp>` de `kubectl get no`) est au statut `Ready`.<br/>• La sortie complète de la commande `kubeadm upgrade apply` (avec la ligne `SUCCESS` et la version cible) est enregistrée littéralement dans `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt` sur la machine de travail (la commande s'exécute sur le nœud, la sortie est écrite dans un fichier sur le nœud, puis copiée par `scp`). |

<details>
<summary>💡 Indice pour la tâche 1</summary>

L'ordre est fondamental : d'abord `apt-mark unhold kubeadm` → mettre à jour le paquet → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`, et seulement APRÈS un `apply` réussi - `drain` et la mise à jour de `kubelet`/`kubectl`. Mettre à jour `kubelet` avant d'appeler `kubeadm upgrade apply` n'est pas nécessaire et n'est pas recommandé par la procédure officielle. Enregistrez la sortie de `kubeadm upgrade apply` dans un fichier sur le nœud (`> /tmp/kubeadm-upgrade-apply.txt 2>&1`), et ne la reconstituez pas de mémoire ensuite - le test cherche le texte littéral contenant le mot `SUCCESS`.
</details>

---
| **2** | **Upgrade du worker vers le minor cible** |
| :---: | :--- |
| Ce qu'on fait | • Sur `k8s113_node_worker1` (`ssh`, `sudo -i`), basculez de façon analogue `pkgs.k8s.io` vers `core:/stable:/v1.36` et mettez à jour `kubeadm`.<br/>• Exécutez `kubeadm upgrade node` (pas `apply` - c'est une commande réservée au control-plane).<br/>• Exécutez `kubectl drain` sur ce nœud (depuis la machine de travail, pas depuis le nœud lui-même).<br/>• Mettez à jour `kubelet`/`kubectl`, redémarrez `kubelet`, exécutez `kubectl uncordon`. |
| Critères d'acceptation | • `kubeadm version`, `kubelet --version` et le `kubectl version --client` local sur le worker indiquent `v1.36.x`.<br/>• `kubectl get nodes` affiche pour le worker `v1.36.x` dans `kubeletVersion` et le statut `Ready`.<br/>• La sortie de `kubeadm upgrade node` est enregistrée dans un fichier sur le nœud et copiée par `scp` vers `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt` sur la machine de travail. |

<details>
<summary>💡 Indice pour la tâche 2</summary>

`kubeadm upgrade node` est précisément la commande pour les workers (et pour les nœuds control-plane supplémentaires), `kubeadm upgrade apply` est destinée uniquement au PREMIER/unique nœud control-plane. Ne commencez cette tâche qu'après que la tâche 1 est entièrement terminée et que le control-plane est déjà `Ready` en `1.36.x` - sinon vous enfreindrez la version skew policy.
</details>

---
| **3** | **Respecter le bon ordre d'upgrade** |
| :---: | :--- |
| Ce qu'on fait | • Réalisez entièrement l'upgrade du control-plane (tâche 1), y compris l'uncordon, AVANT de commencer l'upgrade du worker (tâche 2).<br/>• Cette tâche n'exige aucune action distincte dans le cluster : l'ordre est vérifié automatiquement par le moniteur d'état du cluster et des versions, géré par le checker (checker-owned). |
| Critères d'acceptation | • Le checker-owned monitor consigne la baseline `1.35.x` initiale.<br/>• Ensuite est consigné le passage complet du control-plane en `1.36.x` (y compris `Ready` et schedulable) avec le worker en `1.35.x`, et seulement après cela le début de l'upgrade du worker.<br/>• L'état survit au redémarrage du moniteur ; l'absence de baseline ou une rupture d'observation de plus de 60 secondes n'est pas comptabilisée. |

<details>
<summary>💡 Indice pour la tâche 3</summary>

Si vous avez déjà commencé (et, a fortiori, terminé) l'upgrade du worker avant le control-plane - arrêtez-vous : rétrograder le worker vers les paquets `1.35.x` n'est pas possible par un moyen simple ; la bonne voie consiste à terminer l'upgrade du control-plane, puis à poursuivre/répéter l'upgrade du worker. L'essentiel est que le prochain upgrade du worker (quel que soit le moment où il est lancé) ait lieu après l'upgrade du control-plane entièrement terminé. Ne commencez pas la tâche 2 tant que `kubectl get node <nom-cp>` (nom du control-plane issu de `kubectl get no`) n'affiche pas `v1.36.x` et `Ready`.
</details>

---
| **4** | **Démontrer l'absence de downtime de la charge existante** |
| :---: | :--- |
| Ce qu'on fait | • Pendant que vous exécutez les tâches 1-2, lancez dans une session distincte sur la machine de travail une boucle qui interroge la disponibilité du Deployment `canary` dans le namespace `upgrade-113` toutes les quelques secondes.<br/>• Ajoutez chaque ligne d'interrogation à `/var/work/tests/artifacts/4/canary-availability.log` dans un format contenant `available=N` (par exemple `available=2`).<br/>• Poursuivez l'interrogation pendant toute la durée de l'upgrade des deux nœuds. |
| Critères d'acceptation | • Le Deployment `canary` a à la fin `2/2` répliques disponibles, le Deployment/PDB d'origine et la required Pod anti-affinity sont conservés.<br/>• L'absence de downtime est vérifiée par le checker-owned monitor via Pod Ready et les conteneurs CRI, précisément ceux de `upgrade-113` ; les erreurs API/SSH/CRI sont comptées comme UNKNOWN, et non comme zéro.<br/>• Le fichier de l'étudiant `/var/work/tests/artifacts/4/canary-availability.log` contient au moins deux lignes au format `<unix_timestamp> available=N` ou `<unix_timestamp> available=api-unreachable`, avec des observations avant l'upgrade du control-plane et après le début de l'upgrade du worker. |

<details>
<summary>💡 Indice pour la tâche 4</summary>

Exemple de boucle d'interrogation, que vous pouvez laisser tourner dans un terminal séparé/`screen`/`tmux` pendant toute l'exécution des tâches 1-2 : `while true; do if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then echo "$(date +%s) available=${available:-0}"; else echo "$(date +%s) available=api-unreachable"; fi >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`. Si le Deployment a perdu toutes ses répliques pendant un court instant - vérifiez `kubectl get pods -n upgrade-113 -o wide` et que les drain successifs respectent le PDB et la required anti-affinity.
</details>

## Vérification

```bash
check_result
```

La vérification contient `0 Init` et cinq tests obligatoires. Les tests 1-2 vérifient les versions de
`kubeadm`/`kubelet`/du `kubectl` local et le statut `Ready` sur le control-plane et sur le worker
respectivement, ainsi que le fichier de preuve contenant la sortie littérale de `kubeadm upgrade`. Le test 3
vérifie l'ordre de l'upgrade d'après le checker-owned monitor de l'état du cluster, et non d'après
la date de modification des fichiers. Le test 4 vérifie que la charge `canary` n'a pas connu d'interruption,
en utilisant le même checker-owned monitor comme source de vérité. Le test 5 est la vérification
finale que les deux nœuds sont réellement sur la version cible et ne sont pas restés à l'état
`cordon`.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=113 make delete_cks_task
```
