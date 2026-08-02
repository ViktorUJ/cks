[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 — Troubleshooting : on répare des ressources cassées

## Description

Travail pratique sur le domaine Troubleshooting (30 % du CKA). Des objets **cassés** sont
déjà déployés dans le cluster — votre tâche est de trouver et d'éliminer les causes en
appliquant un parcours de débogage systématique : `get` → `describe` (Events) → `logs` →
réparation. Les tâches imitent des incidents typiques : ImagePullBackOff, Endpoints vides à
cause d'un sélecteur incorrect et CreateContainerConfigError à cause d'un ConfigMap
manquant.

Toutes les tâches sont rédigées dans le style de l'examen (comme les vraies questions
CKA/CKAD) avec une vérification automatique via la commande `check_result`.

## Objectif

Consolider le contenu des chapitres du cours :

- [Chapitre 44. Débogage des pannes d'applications](../../course/44/fr.md) — le parcours `get` → `describe` → `logs`, analyse des statuts des Pods
- [Chapitre 45. Débogage du control plane et des nœuds worker](../../course/45/fr.md) — diagnostic des nœuds et des composants système
- [Chapitre 46. Débogage des services et du réseau](../../course/46/fr.md) — la chaîne Service ↔ Endpoints ↔ labels

## Ce que nous réparons et pourquoi

Dans ce lab, nous réparons trois incidents indépendants : une image défectueuse, un lien
rompu entre le Service et les pods, et une configuration manquante. Chaque panne travaille
sa propre portion du parcours de débogage :

| Panne | Symptôme | Cause | Ce que ça apprend |
|-------|----------|-------|-------------------|
| **ReplicaSet `rs-app2223`** (namespace `rsapp`) | ImagePullBackOff | tag d'image incorrect | analyse des problèmes d'image et recréation des Pods du RS (chapitre 44) |
| **Service `svc-broken`** (namespace `tsvc`) | Endpoints vides | le selector ne correspond pas aux label des Pods | la chaîne Service ↔ Endpoints ↔ labels (chapitre 46) |
| **Deployment `capp`** (namespace `cfgapp`) | CreateContainerConfigError | le ConfigMap nécessaire est absent | dépendances de configuration (chapitre 44) |

Vue d'ensemble de ce qui sera déployé :

```mermaid
flowchart LR
    a["rs-app2223<br>ImagePullBackOff"] -->|"fix image"| a2["2 ready"]
    b["svc-broken<br>Endpoints vides"] -->|"fix selector"| b2["Endpoints présents"]
    c["capp<br>CreateContainerConfigError"] -->|"create ConfigMap"| c2["Ready"]
    a2 ~~~ b
    b2 ~~~ c
    style a fill:#db4437,color:#fff
    style b fill:#db4437,color:#fff
    style c fill:#db4437,color:#fff
    style a2 fill:#0f9d58,color:#fff
    style b2 fill:#0f9d58,color:#fff
    style c2 fill:#0f9d58,color:#fff
```

## Infrastructure

L'environnement est déployé dans AWS (`eu-central-1`) via Terragrunt et se compose de :

| Composant  | Description                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` avec des sous-réseaux publics                     |
| `ssh-keys` | Clés SSH pour l'accès aux nœuds                                      |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, mono-nœud ; déploie les objets cassés au démarrage |
| `worker`   | Machine de travail avec `kubectl` et `check_result`                  |

Instances : `t3.medium` (master), Ubuntu `22.04`. Le cluster est mono-nœud — le taint
`control-plane` a été retiré du master, les pods sont donc planifiés directement dessus.

## Déploiement

```bash
TASK=114 make run_cka_task
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

---
|        **1**        | **Réparer le ReplicaSet**                                   |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Dans le namespace `rsapp`, les Pods du ReplicaSet `rs-app2223` restent bloqués en `ImagePullBackOff`. Suivez le parcours : `kubectl get po -n rsapp` (on voit le statut), `kubectl describe po -n rsapp <pod>` (dans Events — l'image `viktoruj/ping_pong:doesnotexist123` ne se télécharge pas). Corrigez l'image dans le template du RS vers une image fonctionnelle (`viktoruj/ping_pong:latest`) via `kubectl edit rs rs-app2223 -n rsapp`. Le RS ne recrée pas les Pods lors d'un changement de template — supprimez les anciens Pods (`kubectl delete po -n rsapp -l <label>`) pour que le RS en démarre de nouveaux. Obtenez `2` réplicas prêts. |
| Critères d'acceptation | - ReplicaSet `rs-app2223` (namespace `rsapp`) : `2` réplicas Ready. |
---
|        **2**        | **Réparer le Service (Endpoints vides)**                     |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Le Service `svc-broken` du namespace `tsvc` ne délivre pas de trafic — ses Endpoints sont vides. Diagnostic : `kubectl get endpoints svc-broken -n tsvc` (vide), `kubectl describe svc svc-broken -n tsvc` (selector, par exemple `app=WRONG`), `kubectl get pods -n tsvc --show-labels` (les Pods portent le label `app=web`). Alignez le selector du Service sur les label réels des Pods (`kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'`) et assurez-vous que les Endpoints se sont remplis. |
| Critères d'acceptation | - Service `svc-broken` (namespace `tsvc`) : les Endpoints ne sont pas vides (≥ 1 adresse). |
---
|        **3**        | **Réparer le Deployment (ConfigMap absent)**                 |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Le Deployment `capp` du namespace `cfgapp` tombe en `CreateContainerConfigError`. Le parcours : `kubectl get po -n cfgapp` (on voit le statut), `kubectl describe po -n cfgapp <pod>` (dans Events — le ConfigMap `missing-config` n'est pas trouvé). Créez le ConfigMap manquant (`kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value`) et attendez que le déploiement devienne prêt (`kubectl rollout status deploy capp -n cfgapp`). |
| Critères d'acceptation | - Deployment `capp` (namespace `cfgapp`) : ≥ 1 réplica Ready. |
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

Le lab couvre les tâches de troubleshooting des examens blancs : CKAD mock 01 (n° 4 — fix
ReplicaSet) ; la compétence générale de troubleshooting de CKA mock 01/02 (analyse des
statuts, Endpoints, configuration) et CKAD mock 02 (n° 7/n° 8 — fix ingress/netpol).

## Suppression du cluster et des ressources

```bash
TASK=114 make delete_cka_task
```
