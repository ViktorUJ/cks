[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 121 — Drills : RBAC

## Description

Entraînement de vitesse sur RBAC : de courtes tâches indépendantes portant sur
ServiceAccount, Role/RoleBinding, ClusterRole/ClusterRoleBinding et la vérification des
droits effectifs avec `kubectl auth can-i`. Le namespace `rbac` est créé à l'avance.

Les tâches sont rédigées dans le style de l'examen, avec une vérification automatique par
la commande `check_result`. Le but d'un drill n'est pas la théorie, mais la vitesse et la
mémoire musculaire : « se faire la main » sur la création impérative des objets RBAC et
tenir le rythme de l'examen.

## Objectif

Consolider le contenu des chapitres du cours :

- [Chapitre 21. ServiceAccount ; authentification, autorisation, admission](../../course/21/fr.md) — ServiceAccount, la chaîne authn/authz/admission
- [Chapitre 38. RBAC : Role, ClusterRole et bindings](../../course/38/fr.md) — Role/ClusterRole, RoleBinding/ClusterRoleBinding, vérification des droits avec `auth can-i`

## Ce que nous faisons et pourquoi

| Bloc | Tâches | Compétence |
|------|--------|------------|
| **RBAC dans un namespace** | ServiceAccount `app-sa`, Role `pod-reader`, RoleBinding `read-pods` | droits limités à un namespace via Role + binding (chapitre 38) |
| **RBAC à l'échelle du cluster** | ClusterRole `cr-viewer`, ClusterRoleBinding `crb-viewer` | accès aux ressources du cluster (nodes) via ClusterRole (chapitre 38) |
| **Vérification des droits** | `kubectl auth can-i` pour `app-sa` | validation rapide des droits effectifs d'un ServiceAccount (chapitre 21) |

## Infrastructure

L'environnement est déployé dans AWS (`eu-central-1`) via Terragrunt et se compose de :

| Composant  | Description                                                                     |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` avec des sous-réseaux publics                                |
| `ssh-keys` | Clés SSH pour l'accès aux nodes                                                  |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, un seul node ; le namespace `rbac` est créé à l'avance |
| `worker`   | Machine de travail avec `kubectl` et `check_result`                             |

Instances : `t3.medium` (master), Ubuntu `22.04`. Le cluster est mononœud — le taint
`control-plane` a été retiré du master, les pods sont donc planifiés directement dessus.

## Déploiement

```bash
TASK=121 make run_cka_task
```

Après la création, connecte-toi en SSH à la machine de travail (worker) et effectue les
tâches depuis celle-ci. `kubectl` est déjà configuré sur le contexte
`cluster1-admin@cluster1`.

Commandes utiles sur la machine de travail :

```bash
time_left       # temps restant
check_result    # vérifier la solution
```

## Tâches

---
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| Ce que nous faisons | Crée le ServiceAccount `app-sa` dans le namespace `rbac` (`kubectl -n rbac create serviceaccount app-sa`). |
| Critères d'acceptation | - le ServiceAccount `app-sa` existe dans le namespace `rbac`. |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| Ce que nous faisons | Crée le Role `pod-reader` dans le namespace `rbac` avec les droits `get,list,watch` sur la ressource `pods` (`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`). |
| Critères d'acceptation | - le Role `pod-reader` accorde `get`/`list`/`watch` sur `pods`. |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Ce que nous faisons | Crée le RoleBinding `read-pods` dans le namespace `rbac`, en liant le Role `pod-reader` au sujet ServiceAccount `app-sa` (`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`). |
| Critères d'acceptation | - le RoleBinding `read-pods` référence le Role `pod-reader` et le sujet `app-sa`. |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Ce que nous faisons | Crée le ClusterRole `cr-viewer` avec les droits `get,list` sur la ressource de cluster `nodes` (`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`). |
| Critères d'acceptation | - le ClusterRole `cr-viewer` accorde `get`/`list` sur `nodes`. |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| Ce que nous faisons | Crée le ClusterRoleBinding `crb-viewer`, en liant le ClusterRole `cr-viewer` au sujet ServiceAccount `app-sa` du namespace `rbac` (`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`). |
| Critères d'acceptation | - le ClusterRoleBinding `crb-viewer` référence le ClusterRole `cr-viewer` et le sujet `rbac/app-sa`. |
---
|        **6**        | **Vérification des droits (auth can-i)**                    |
| :-----------------: | :----------------------------------------------------------- |
| Ce que nous faisons | Vérifie les droits effectifs de `app-sa` avec `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa` : `get pods` dans `rbac`, `get nodes` et `delete pods` dans `rbac`. Assure-toi que les liaisons sont accordées correctement. |
| Critères d'acceptation | - `get pods` dans le namespace `rbac` = `yes` ;<br/>- `get nodes` = `yes` ;<br/>- `delete pods` dans le namespace `rbac` = `no`. |
---

## Vérification du résultat

Sur la machine de travail, lance la vérification automatique :

```bash
check_result
```

Le script exécute les tests et affiche le nombre de tâches réussies.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD)

## Couverture des examens blancs

Le domaine Cluster Architecture (RBAC) pour CKA et Application Security pour CKAD —
répétitions de Role/ClusterRole et des liaisons avec un ServiceAccount.

## Suppression du cluster et des ressources

```bash
TASK=121 make delete_cka_task
```
