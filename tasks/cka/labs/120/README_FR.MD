[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 120 — Drills : services et réseau

## Description

Entraîneur de vitesse pour le domaine Services & Networking. Des tâches courtes et
indépendantes sur la création de Services (ClusterIP, NodePort, headless), d'Ingress et de
NetworkPolicy, plus un bloc sur JSONPath.

Les tâches sont rédigées dans le style de l'examen avec une vérification automatique via la
commande `check_result`. L'objectif d'un drill n'est pas d'analyser la théorie, mais la
vitesse et la mémoire musculaire : se faire la main et tenir le rythme de l'examen. Les
fichiers de réponse des tâches JSONPath sont enregistrés dans `/home/ubuntu/answers/`.

## Objectif

Consolider le contenu des chapitres du cours :

- [Chapitre 7. Services : ClusterIP, NodePort, LoadBalancer, Endpoints](../../course/07/fr.md) — types de Service, publication via `expose`, Endpoints
- [Chapitre 31. Le Service de l'intérieur, DNS et CoreDNS](../../course/31/fr.md) — Service headless (`clusterIP: None`), noms DNS
- [Chapitre 32. Ingress et contrôleurs Ingress](../../course/32/fr.md) — routage par hôte et par chemin vers le Service backend
- [Chapitre 34. NetworkPolicy](../../course/34/fr.md) — default-deny, podSelector, policyTypes

## Ce que nous faisons et pourquoi

| Bloc | Tâches | Compétence |
|------|--------|------------|
| **Services** | Deployment `web`, ClusterIP, NodePort, headless | publier rapidement une charge avec différents types de Service (chapitres 7, 31) |
| **Routage et isolation** | Ingress `web-ing`, NetworkPolicy `deny-all` | règles Ingress par hôte et default-deny du trafic (chapitres 32, 34) |
| **JSONPath** | nodePort du Service `web-np` → dans un fichier | extraction de données via `-o jsonpath` contre le chronomètre (chapitre 47) |

## Infrastructure

L'environnement est déployé dans AWS (`eu-central-1`) via Terragrunt et se compose de :

| Composant  | Description                                                          |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` avec des sous-réseaux publics                     |
| `ssh-keys` | Clés SSH pour l'accès aux nœuds                                      |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, mono-nœud  |
| `worker`   | Machine de travail avec `kubectl` et `check_result`                  |

Instances : `t4g.medium` (master), Ubuntu `22.04`. Le cluster est mono-nœud — le taint
`control-plane` a été retiré du master, les pods sont donc planifiés directement dessus.

## Déploiement

```bash
TASK=120 make run_cka_task
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
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez le namespace (espace de noms) `net`, puis dedans un Deployment `web` avec l'image `viktoruj/ping_pong:latest` et 2 réplicas (`kubectl create ns net`, `kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`). |
| Critères d'acceptation | - Deployment `web` (ns `net`) : 2 réplicas prêts. |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Publiez le Deployment `web` comme Service (service) de type ClusterIP nommé `web-svc` sur le port 80 (`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`). |
| Critères d'acceptation | - Service `web-svc` (ns `net`) : les Endpoints ne sont pas vides. |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez un Service `web-np` de type NodePort pour `web` avec un `nodePort: 30080` fixe (`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`). |
| Critères d'acceptation | - Service `web-np` : type `NodePort`, `nodePort` 30080. |
---
|        **4**        | **Service headless**                                        |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez un Service headless `web-h` avec `clusterIP: None` pour les Pods `web` (sélecteur `app=web`). Un Service headless distribue les enregistrements DNS directement vers les Pods, sans passer par l'IP virtuelle. |
| Critères d'acceptation | - Service `web-h` : `clusterIP` = `None`. |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez un Ingress `web-ing` dans le namespace `net` : l'hôte `web.local`, le chemin `/` dirige vers le Service backend `web-svc` port 80 (`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`). |
| Critères d'acceptation | - Règle d'hôte `web.local` → backend Service `web-svc`, port 80. |
---
|        **6**        | **NetworkPolicy (default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Créez une NetworkPolicy `deny-all` dans le namespace `net` avec un `podSelector: {}` vide (s'applique à tous les Pods) et `policyTypes: [Ingress]` — la politique interdit tout le trafic entrant. |
| Critères d'acceptation | - NetworkPolicy `deny-all` : `policyTypes` contient `Ingress`, `podSelector` est vide. |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Ce qu'on fait       | Extrayez le `nodePort` du Service `web-np` via `-o jsonpath` et enregistrez-le dans `/home/ubuntu/answers/nodeport.txt` (chemin `{.spec.ports[0].nodePort}`). |
| Critères d'acceptation | - La valeur dans `nodeport.txt` correspond à `.spec.ports[0].nodePort` du Service `web-np`. |
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

Domaine Services & Networking (20 % CKA / 20 % CKAD) — révisions de base des Services, de
l'Ingress et de la NetworkPolicy.

## Suppression du cluster et des ressources

```bash
TASK=120 make delete_cka_task
```
