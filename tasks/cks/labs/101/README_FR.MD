[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 101 - NetworkPolicy : default-deny, isolation et EC2 IMDS

## Description

`NetworkPolicy` fonctionne comme une allow-list : après default-deny, les flux nécessaires ne sont rétablis que par des règles explicites. L'application effective des règles est assurée par Calico. Le worker de ce lab est une instance EC2 gérée par Terraform ; son Instance Metadata Service (IMDS) est disponible à l'adresse `http://169.254.169.254/`. Terraform active explicitement le HTTP endpoint, laisse le GET IMDSv1 autorisé pour un probe sûr et fixe le response hop limit à `2`, afin qu'avant default-deny un Pod ordinaire puisse confirmer l'accessibilité réseau d'IMDS.

Le lab ne vérifie que l'accessibilité réseau de l'IMDS endpoint, sans lire de metadata ni de credentials. Tout HTTP status `1xx–5xx` effectivement reçu signifie qu'un chemin TCP/HTTP vers IMDS existe. Le code `000` (`HTTP:000` dans les commandes de la solution, `HTTPCODE:000` dans la sortie du checker) accompagné d'un transport error/timeout signifie l'absence de réponse HTTP. Le HTTP status concret dépend des EC2 metadata options : si le token usage est `required`, un GET sans IMDSv2 token valide reçoit `401` ; si IMDSv1 est autorisé, un GET tokenless est traité comme une requête IMDSv1 et peut recevoir une HTTP response normale.

**Risque résiduel.** Le worker EC2 a un IAM instance profile attaché, et un GET tokenless IMDSv1 vers `latest/meta-data/iam/security-credentials/<role>` renvoie réellement des credentials AWS temporaires (AccessKeyId/SecretAccessKey/SessionToken) - ce n'est pas un risque hypothétique, mais le comportement réel de l'environnement actuel. Le rôle lui-même est limité à des droits quasi nuls (least privilege : il ne peut même pas lire son propre IAM role via `iam:GetRole`), de sorte que la valeur pratique de la fuite pour un attaquant est minimale, mais l'étudiant doit comprendre explicitement qu'en production, avec la même configuration (`HttpTokens=optional`, IMDSv1 autorisé), cette même commande renverrait les vrais credentials du rôle de production, avec de vrais droits. Le lab reproduit volontairement cet anti-pattern du chapitre 02.1 (IMDSv1 allowed, response hop limit `2`) à des fins de probe et pour apprendre à trouver cette vulnérabilité via NetworkPolicy ; en production, utilisez `HttpTokens=required` (IMDSv2 uniquement) et `HttpPutResponseHopLimit=1`.

## Déploiement

Sur la machine de gestion, lancez l'environnement :

```bash
TASK=101 make run_cks_task
```

Après un déploiement réussi, Terraform affichera la commande SSH pour se connecter au worker. Elle aura ce format :

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Par exemple :

```
18:53:06.019 STDOUT [worker] terraform: worker_pc_ssh = "ssh ubuntu@18.193.110.150 password= fq0J9RuZWN"
```

Pour vous connecter, utilisez uniquement l'adresse de la commande :

```bash
ssh ubuntu@<IP>
```

Lorsque SSH demande le mot de passe, saisissez la valeur affichée par Terraform après `password=`.

**Pour les vérifications runtime**, utilisez un Pod de diagnostic temporaire avec les mêmes labels que l'identity vérifiée. Pour les vérifications HTTP, il faut une image avec curl (`curlimages/curl:8.11.1`) ; pour le DNS, une image avec nslookup (`busybox:1.36.1`). Après la vérification, supprimez les Pods temporaires et les policies temporaires.

Travaillez sur le worker. Avant de commencer, assurez-vous que les namespaces sont propres (par précaution) :

```bash
kubectl delete namespace cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true
printf 'EC2 IMDS target: %s\n' 'http://169.254.169.254/'
time_left
```

Vérifiez chaque étape par vous-même sur vos propres ressources ; lancez `check_result` après avoir réalisé les tâches, et n'ouvrez la solution de référence qu'après votre propre tentative ou en cas de difficulté.

## Objectif

Configurer une allow-list ingress/egress minimale, figer l'image digest, démontrer la sémantique AND du selector et l'`ipBlock.except` exact pour IMDS, puis comparer un Pod ordinaire avec un Pod en `hostNetwork`, sans supposer à l'avance un résultat universel.

## Infrastructure

| Composant | Rôle |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| `cks-101`        | namespace de l'application et de vos `NetworkPolicy` |
| `cks-101-legacy` | namespace du scénario du client legacy |
| `imds-control`   | namespace indépendant sans policy pour le baseline et pour le control probe répété |
| worker EC2       | instance EC2 gérée par Terraform avec IMDS `http://169.254.169.254/` |
| CNI                | Calico |

## Tâches

---

|           **1**           | **Application** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Ce qu'on fait       | Namespace `cks-101` ; Deployments `frontend` et `backend` avec `replicas: 1`, sans `hostNetwork`, avec le même `viktoruj/ping_pong@sha256:<64hex>` ; Service `backend` TCP/8080.<br/><br/>**Comment obtenir le digest actuel :**<br/>1. Lancez temporairement un Pod à partir de l'image `viktoruj/ping_pong:latest`.<br/>2. Attendez le pull et Ready.<br/>3. Exécutez `digest=$(kubectl get pod <pod_name> -o yaml \| grep imageID \| cut -d'@' -f2)` et obtenez `sha256:<64hex>`.<br/>4. Supprimez le Pod temporaire.<br/>5. Utilisez le digest obtenu pour les deux Deployments : `viktoruj/ping_pong@sha256:<64hex>`. |
| Critères d'acceptation | Les deux replicas sont Ready, les image references sont identiques, le Service a un endpoint. |
|        Vérification        | Exécutez `kubectl -n cks-101 get deploy,svc,endpoints` et assurez-vous que :<br/>1. Les deux Deployments ont `1/1 Ready`.<br/>2. Le Service `backend` a un endpoint.<br/><br/>Pour vérifier la pinned image, exécutez :<br/>`kubectl -n cks-101 get deploy frontend backend -o yaml \| grep 'image:'`<br/>Les deux Deployments doivent utiliser la même image de la forme `viktoruj/ping_pong@sha256:<64hex>`. |

---

|           **2**           | **Baseline, default-deny et probe répété** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | Créez le namespace `imds-control` et un curl Pod temporaire. Créez le frontend probe dans `cks-101`. **Avant `default-deny`**, confirmez deux baselines : frontend → backend et frontend → IMDS sont accessibles ; `imds-control` → IMDS est également accessible. Créez ensuite `default-deny`. **Après `default-deny`**, répétez les IMDS probes : frontend doit recevoir `HTTP 000` et curl `7`/`28`, et `imds-control` doit continuer à recevoir un vrai HTTP `1xx–5xx` avec exit `0`. Le deny du backend est vérifié dans Task 3, après le rétablissement du DNS. |
| Critères d'acceptation | Avant le deny, backend et IMDS sont réellement accessibles. Après le deny, frontend → IMDS donne `HTTP 000` + curl `7`/`28` ; l'`imds-control` indépendant conserve HTTP `1xx–5xx` + exit `0`. |
|        Vérification        | 1. Avant `default-deny` : curl depuis le frontend probe vers `http://backend:8080/` doit recevoir une HTTP response + exit `0`.<br/>2. Avant `default-deny` : frontend et `imds-control` doivent recevoir une vraie HTTP response d'IMDS.<br/>3. Vérifiez `default-deny` : `podSelector` vide, `Ingress` + `Egress`, sans allow-rules.<br/>4. Après `default-deny` : frontend → IMDS doit renvoyer `HTTP 000` + curl `7`/`28` ; `imds-control` → IMDS doit toujours recevoir HTTP `1xx–5xx` + exit `0`.<br/>5. Ne vérifiez pas le deny du backend avant le rétablissement du DNS - il est vérifié dans Task 3. |

---

|           **3**           | **DNS** |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | Après `default-deny`, en tant que première allow-rule, rendez au frontend l'accès uniquement à `kube-system/kube-dns` sur les ports exacts UDP/53 et TCP/53, sans `endPort`. Pour la vérification, créez un `dns-probe` distinct sur `busybox:1.36.1` avec le label `app=frontend`. |
| Critères d'acceptation | Le DNS allow-set est exactement UDP/53 + TCP/53 ; `nslookup kubernetes.default.svc.cluster.local` fonctionne. À ce stade, le backend ne doit pas encore être accessible sur TCP/8080. |
|        Vérification        | 1. Vérifiez `allow-frontend-dns` dans le YAML : uniquement UDP/53 et TCP/53, sans `endPort` ni ports supplémentaires.<br/>2. Exécutez `nslookup kubernetes.default.svc.cluster.local` depuis `dns-probe`.<br/>3. Après un DNS réussi, exécutez curl depuis le frontend probe vers `http://backend:8080/` : jusqu'à Task 4, on attend `HTTP 000` + curl `7`/`28`. |

---

|           **4**           | **NetworkPolicy pour l'application** |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | Créez `allow-frontend-egress-to-backend` et `allow-backend-ingress-from-frontend`. Ensuite, frontend doit recevoir une vraie HTTP response de `http://backend:8080/`. |
| Critères d'acceptation | Frontend → backend:8080 est autorisé ; une foreign identity reste bloquée. |
|        Vérification        | Positive : curl du frontend via le nom DNS du Service. Negative : un foreign Pod avec une egress policy temporaire vers backend ne doit pas passer le backend ingress. |

---

|           **5**           | **Vérification finale d'IMDS** |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | Après avoir ajouté les policies allow du DNS et de l'application, répétez le même IMDS probe depuis le Pod frontend et depuis l'`imds-control` indépendant. Le but est de démontrer que les nouvelles policies allow n'ont pas ouvert IMDS. Il n'est pas nécessaire de créer des fichiers d'artifact annexes. |
| Critères d'acceptation | `imds-control` : HTTP `1xx–5xx` réel + exit `0` ; frontend : `HTTP 000` + curl `7`/`28`. |
|        Vérification        | Exécutez le même curl borné (`-m 5`) depuis les deux Pods et comparez le résultat réel. N'utilisez pas `curl -f` : un HTTP `401/403/404/...` signifie tout de même une accessibilité réseau. |

---

|           **6**           | **Legacy AND et IMDS except** |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | Créez le namespace `cks-101-legacy` avec le Deployment `legacy-client` : replicas=1, sans hostNetwork, image `curlimages/curl:8.11.1`, commande `sleep 3600`. Créez la NetworkPolicy `allow-backend-ingress-from-legacy` dans le namespace `cks-101` : elle sélectionne backend, contient un seul ingress peer avec AND selector (namespaceSelector et podSelector dans un même élément `from`), TCP/8080. Créez la NetworkPolicy `allow-legacy-egress` dans le namespace `cks-101-legacy` : elle sélectionne app=legacy-client, contient ipBlock cidr=0.0.0.0/0 avec un unique except 169.254.169.254/32, sans allow-rules supplémentaires. Vérifiez : 1) IMDS depuis legacy-client est bloqué ; 2) legacy-client peut atteindre backend ; 3) un Pod avec un autre label dans le même namespace ne passe pas l'ingress ; 4) un Pod avec label=legacy-client dans le namespace cks-101 ne passe pas l'ingress. Après les vérifications, supprimez les Pods temporaires et les policies temporaires. |
| Critères d'acceptation | IMDS bloqué, le flux réel legacy-client → backend autorisé, le Pod avec un label incorrect ou d'un namespace incorrect bloqué. |
|        Vérification        | 1. Exécutez `kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml` - assurez-vous que `ipBlock.cidr=0.0.0.0/0` et que l'unique `except` est `169.254.169.254/32`.<br/>2. Exécutez `kubectl -n cks-101 get networkpolicy allow-backend-ingress-from-legacy -o yaml` - assurez-vous que `namespaceSelector` et `podSelector` sont dans un même élément `from`, port TCP/8080.<br/>3. Curl depuis `legacy-client` vers IMDS doit renvoyer `HTTP 000` et exit `7` ou `28`.<br/>4. Curl depuis `legacy-client` vers backend doit recevoir une vraie HTTP response.<br/>5. Un Pod avec un autre label dans `cks-101-legacy` avec un egress temporaire vers backend ne doit pas passer le backend ingress.<br/>6. Un Pod avec `app=legacy-client` dans le namespace `cks-101` avec un egress temporaire vers backend ne doit pas non plus passer le backend ingress. |

---

|           **7**           | **Observation de hostNetwork** |
| :-----------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | Créez `hostnetwork-probe` avec l'image `curlimages/curl:8.11.1`, le label `app=frontend` et `spec.hostNetwork=true`. Exécutez depuis ce Pod le même curl vers IMDS que celui utilisé pour le Pod frontend ordinaire. Comparez l'observation réelle avec Task 5. Il n'est pas nécessaire de créer des fichiers d'artifact annexes. |
| Critères d'acceptation | Pod Ready, `hostNetwork=true`, IMDS probe réel exécuté. Pour hostNetwork, aucun résultat attendu universel n'est présumé : le comportement dépend du CNI et de la configuration du nœud. |
|        Vérification        | Vérifiez `hostNetwork: true`, puis exécutez un curl borné (`-m 5`) vers IMDS et `echo $?`. Comparez l'observation réelle avec le Pod ordinaire de Task 5. |

## Vérification

```bash
check_result
```

Le checker crée et supprime son propre namespace `imds-control` et ses propres probes : avant et après le deny dans `cks-101`, il confirme que l'IMDS réel répond depuis un namespace indépendant sans policy. Il ne fait pas confiance aux ressources de contrôle d'une tentative précédente et ne remplace pas vos propres vérifications de baseline/runtime. Les policies supplémentaires qui élargissent les flux autorisés provoquent une erreur.

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=101 make delete_cks_task
```
