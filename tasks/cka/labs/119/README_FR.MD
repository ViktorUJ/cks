[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 119 — Exercices de vitesse et JSONPath

## Description

Un entraînement à la vitesse pour CKA/CKAD : des tâches courtes et répétitives sur la
création impérative d'objets (Pod, Deployment, Service, ConfigMap, Secret) et un bloc à part
consacré à `-o jsonpath` — extraire des données des objets du cluster vers des fichiers.

Les tâches sont rédigées dans le style de l'examen, avec une vérification automatique via la
commande `check_result`. Le but de l'exercice n'est pas de revoir la théorie mais de gagner
en vitesse et en mémoire musculaire : acquérir de l'aisance avec les commandes impératives et
tenir le rythme de l'examen (~6-8 minutes par tâche). Les fichiers de réponses des tâches
JSONPath sont enregistrés dans `/home/ubuntu/answers/`.

## Objectif

Consolider le contenu des chapitres du cours :

- [Chapitre 3. Travailler avec kubectl : approches impérative et déclarative](../../course/03/fr.md) — commandes impératives rapides, `--dry-run=client -o yaml`, générateurs d'objets
- [Chapitre 47. Examen CKAD : JSONPath et productivité avec kubectl](../../course/47/fr.md) — extraction de données via `-o jsonpath`, custom-columns, `--sort-by`
- [Chapitre 48. Examen CKA : gestion du temps et stratégie](../../course/48/fr.md) — répartition du temps et ordre de résolution des tâches

## Ce que nous faisons et pourquoi

| Bloc | Tâches | Compétence |
|------|--------|------------|
| **Exercices** | namespace, Deployment, Service, ConfigMap, Secret | vitesse des commandes impératives, `--dry-run` (chapitre 3) |
| **JSONPath** | versions des nodes, images des Pods, ClusterIP du Service → dans des fichiers | `-o jsonpath`, extraction de données chronométrée (chapitre 47) |

## Infrastructure

L'environnement est déployé dans AWS (`eu-central-1`) via Terragrunt et se compose de :

| Composant  | Description                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` avec des sous-réseaux publics                     |
| `ssh-keys` | Clés SSH pour l'accès aux nodes                                      |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, mono-node |
| `worker`   | Machine de travail avec `kubectl` et `check_result`                  |

Instances : `t4g.medium` (master), Ubuntu `22.04`. Le cluster est mono-node — le taint
`control-plane` a été retiré du master, les Pods y sont donc planifiés directement.

## Déploiement

```bash
TASK=119 make run_cka_task
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
|        **1**        | **Namespace**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Que faisons-nous    | Créez le namespace (espace de noms) `drill` — c'est là que vivront les objets des autres tâches (`kubectl create namespace drill`). |
| Critères d'acceptation | - le namespace `drill` existe. |
---
|        **2**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Que faisons-nous    | Dans le namespace `drill`, créez un Deployment `api` avec l'image `viktoruj/ping_pong:latest` et 3 réplicas (`kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3`). |
| Critères d'acceptation | - Deployment `api` dans `drill` : 3 réplicas prêts. |
---
|        **3**        | **Service**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Que faisons-nous    | Publiez le Deployment `api` en tant que Service (service) de type ClusterIP nommé `api-svc` sur le port 80 (`kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080`). |
| Critères d'acceptation | - Service `api-svc` (ns `drill`) : les Endpoints ne sont pas vides. |
---
|        **4**        | **ConfigMap et Secret**                                     |
| :-----------------: | :----------------------------------------------------------- |
| Que faisons-nous    | Dans le namespace `drill`, créez un ConfigMap `cfg` avec la clé `APP_COLOR=blue` et un Secret `sec` avec la clé `PASSWORD` (valeur au choix). Utilisez `--from-literal`. |
| Critères d'acceptation | - `cfg.data.APP_COLOR=blue` ;<br/>- le Secret `sec` possède la clé `PASSWORD`. |
---
|        **5**        | **JSONPath : versions des nodes**                           |
| :-----------------: | :----------------------------------------------------------- |
| Que faisons-nous    | Extrayez le `kubeletVersion` de tous les nodes via `-o jsonpath` et enregistrez le résultat dans le fichier `/home/ubuntu/answers/versions.txt` (chemin `{.items[*].status.nodeInfo.kubeletVersion}`). |
| Critères d'acceptation | - Le contenu de `versions.txt` correspond à la sortie de `jsonpath` sur les nodes. |
---
|        **6**        | **JSONPath : images des Pods**                              |
| :-----------------: | :----------------------------------------------------------- |
| Que faisons-nous    | Extrayez les images des conteneurs de tous les Pods du namespace `drill` via `-o jsonpath` et enregistrez-les dans `/home/ubuntu/answers/images.txt` (chemin `{.items[*].spec.containers[*].image}`). |
| Critères d'acceptation | - L'ensemble des images dans `images.txt` correspond à la sortie de `jsonpath` sur les Pods de `drill`. |
---
|        **7**        | **JSONPath : ClusterIP du Service**                         |
| :-----------------: | :----------------------------------------------------------- |
| Que faisons-nous    | Extrayez le ClusterIP du Service `api-svc` via `-o jsonpath` et enregistrez-le dans `/home/ubuntu/answers/api-ip.txt` (chemin `{.spec.clusterIP}`). |
| Critères d'acceptation | - La valeur dans `api-ip.txt` correspond au `.spec.clusterIP` du Service `api-svc`. |
---

## Vérification du résultat

Sur la machine de travail, lancez la vérification automatique :

```bash
check_result
```

Le script exécute les tests et montre combien de tâches sont réussies.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD)

## Couverture des examens blancs

Compétences de base en vitesse et en JSONPath, sollicitées dans tous les examens blancs CKA
et CKAD.

## Suppression du cluster et des ressources

```bash
TASK=119 make delete_cka_task
```
