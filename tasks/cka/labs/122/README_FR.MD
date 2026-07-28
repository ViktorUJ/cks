[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 122 — Exercices : planification des pods

## Description

Un entraîneur de vitesse pour le domaine Workloads & Scheduling : de courtes tâches
indépendantes sur nodeSelector, nodeAffinity, requests/limits, PriorityClass et
taints/tolerations. Le cluster est mono-nœud — les labels et les taints sont posés sur
l'unique nœud.

Les tâches sont rédigées dans le style de l'examen, avec une vérification automatique via
la commande `check_result`. L'objectif de l'exercice n'est pas la théorie, mais la vitesse
et la mémoire musculaire : se faire la main sur la planification des Pods et tenir le rythme
de l'examen.

> **Important :** faites la tâche 6 (taint) en dernier — le taint `NoSchedule` empêche de
> planifier des Pods sans toleration.

## Objectif

Consolider le contenu des chapitres du cours :

- [Chapitre 12. Planification des pods : nodeName, nodeSelector, affinity](../../course/12/ru.md) — rattacher les Pods aux nœuds via nodeSelector et nodeAffinity
- [Chapitre 13. Taints et tolerations](../../course/13/ru.md) — repousser les Pods avec des taints et les admettre avec des tolerations
- [Chapitre 14. Ressources : requests, limits, LimitRange, ResourceQuota](../../course/14/ru.md) — requests et limits CPU/mémoire par conteneur
- [Chapitre 15. Static Pods, PriorityClass, plusieurs planificateurs](../../course/15/ru.md) — priorité des Pods via PriorityClass

## Ce que nous faisons et pourquoi

| Bloc | Tâches | Compétence |
|------|--------|------------|
| **Rattachement à un nœud** | label `disk=ssd`, Pod `sel` (nodeSelector), Pod `aff` (nodeAffinity) | diriger les Pods vers les nœuds voulus (chapitre 12) |
| **Ressources et priorité** | Pod `res` (requests/limits), PriorityClass `high-prio` + Pod `prio` | requests/limits et priorité de planification (chapitres 14, 15) |
| **Taints et tolerations** | taint `dedicated=special:NoSchedule` + Pod `tol` | isoler un nœud avec un taint et l'admettre via une toleration (chapitre 13) |

## Infrastructure

L'environnement est déployé dans AWS (`eu-central-1`) via Terragrunt et se compose de :

| Composant  | Description                                                                     |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` avec des sous-réseaux publics                                |
| `ssh-keys` | Clés SSH pour l'accès aux nœuds                                                  |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, mono-nœud ; le namespace `sched` est créé à l'avance |
| `worker`   | Machine de travail avec `kubectl` et `check_result`                             |

Instances : `t3.medium` (master), Ubuntu `22.04`. Le cluster est mono-nœud — le taint
`control-plane` a été retiré du master, les pods sont donc planifiés directement dessus.

## Déploiement

```bash
TASK=122 make run_cka_task
```

Après la création, connectez-vous en SSH à la machine de travail (worker) et effectuez les
tâches depuis celle-ci. `kubectl` est déjà configuré sur le contexte
`cluster1-admin@cluster1`.

Commandes utiles sur la machine de travail :

```bash
time_left       # combien de temps il reste
check_result    # vérifier la solution
```

## Tâches

Il est pratique de mettre le nom de l'unique nœud dans une variable :
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`.

---
|        **1**        | **Label sur le nœud**                                       |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Posez sur le nœud le label `disk=ssd` (`kubectl label node $NODE disk=ssd`). |
| Critères d'acceptation | - le nœud possède le label `disk=ssd`. |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez le Pod `sel` (ns `sched`, image `viktoruj/ping_pong:latest`) avec `nodeSelector: disk=ssd` — le Pod n'est planifié que sur un nœud portant ce label. |
| Critères d'acceptation | - le Pod `sel` est en état `Running`, `nodeSelector` `disk=ssd`. |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez le Pod `aff` (ns `sched`, image `viktoruj/ping_pong:latest`) avec une nodeAffinity required : clé `disk`, opérateur `In`, valeurs `[ssd]` (`requiredDuringSchedulingIgnoredDuringExecution`). |
| Critères d'acceptation | - le Pod `aff` est en état `Running`, la nodeAffinity est définie. |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez le Pod `res` (ns `sched`, image `viktoruj/ping_pong:latest`) avec les requests `cpu=100m`, `memory=64Mi` et les limits `cpu=200m`, `memory=128Mi` sur le conteneur. |
| Critères d'acceptation | - le Pod `res` est en état `Running`, les limits `cpu` et `memory` sont définies. |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez la PriorityClass `high-prio` avec la valeur `value: 1000` (`kubectl create priorityclass high-prio --value=1000`), puis le Pod `prio` (ns `sched`, image `viktoruj/ping_pong:latest`) avec `priorityClassName: high-prio`. |
| Critères d'acceptation | - PriorityClass `high-prio` `value=1000` ;<br/>- le Pod `prio` est en état `Running` avec `priorityClassName: high-prio`. |
---
|        **6**        | **Taint + toleration** (en dernier)                         |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Posez sur le nœud le taint `dedicated=special:NoSchedule` (`kubectl taint node $NODE dedicated=special:NoSchedule`), puis créez le Pod `tol` (ns `sched`, image `viktoruj/ping_pong:latest`) avec la toleration correspondante (`key=dedicated`, `operator=Equal`, `value=special`, `effect=NoSchedule`). **Faites cette tâche en dernier** — le taint empêchera de planifier les autres Pods. |
| Critères d'acceptation | - le nœud possède le taint `dedicated=special:NoSchedule` ;<br/>- le Pod `tol` est en état `Running`. |
---

## Vérification du résultat

Sur la machine de travail, lancez la vérification automatique :

```bash
check_result
```

Le script exécute les tests et affiche le nombre de tâches réussies.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD)

## Couverture des examens blancs

Le domaine Workloads & Scheduling (15 % CKA) — révisions de nodeSelector/affinity, des
ressources, de PriorityClass, des taints/tolerations.

## Suppression du cluster et des ressources

```bash
TASK=122 make delete_cka_task
```
