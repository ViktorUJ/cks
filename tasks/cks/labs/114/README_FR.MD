[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 - Kubeconfig contexts, client certificates et API exposure

## Description

Le kubeconfig remis à l'étudiant contient plusieurs contexts : un `cluster1-admin@cluster1` fonctionnel
et deux contexts manifestement non fonctionnels (`staging-admin@staging`, `legacy-admin@legacy`), qui pointent vers des
API server inexistants. Juste après la connexion, `current-context` est positionné sur le `staging-admin@staging` non fonctionnel - cela
reproduit volontairement une situation réelle de l'examen, où l'on remet au candidat un kubeconfig avec plusieurs
contexts et où il doit déterminer lui-même lequel est fonctionnel.

Séparément, dans le même kubeconfig, il y a un utilisateur `cluster9-admin` avec un client certificate auto-signé complet,
réellement généré (`client-certificate-data`/`client-key-data`). Ce certificat ne donne
aucun droit dans le cluster (son CA n'est approuvé par aucun apiserver) - la tâche apprend à lire et à analyser
un client certificate depuis le kubeconfig, et non à s'authentifier avec lui.

Le lab couvre aussi le scénario classique de réduction de la surface d'attaque d'un Service : d'abord vous
créez volontairement un Service `NodePort` (accessible de l'extérieur sur l'IP du nœud control-plane), puis vous le réduisez à
`ClusterIP`, en démontrant l'effet en direct dans les deux sens.

## Déploiement

Sur la machine de gestion, lancez l'environnement :

```bash
TASK=114 make run_cks_task
```

Après un déploiement réussi, Terraform affichera la commande SSH de connexion au worker :

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Connectez-vous uniquement à l'adresse issue de la sortie de Terraform :

```bash
ssh ubuntu@<IP>
```

Travaillez sur le worker. Vérifiez vous-même chaque étape ; lancez `check_result` après avoir exécuté
les tâches, n'ouvrez la solution de référence qu'après votre propre tentative ou en cas de difficulté.

## Objectif

Apprendre à travailler en toute sécurité avec un kubeconfig contenant plusieurs contextes, à extraire et à vérifier
un client certificate sans l'utiliser pour l'authentification, et à gérer consciemment l'exposure d'un Service
en basculant de `NodePort` -> `ClusterIP`.

## Infrastructure

| Composant | Rôle |
| --- | --- |
| kubeconfig (`~/.kube/config`) | 4 contexts : 1 fonctionnel (`cluster1-admin@cluster1`), 2 decoy (`staging-admin@staging`, `legacy-admin@legacy`), 1 avec un vrai client certificate (`cluster9-admin@cluster1`) |
| `cks-114` | namespace de votre application backend et du Service |
| control-plane EC2 | cluster kubeadm mono-nœud, CNI Calico |

## Tâches

---

|           **1**           | **Kubeconfig context inventory**                                                                                                                                                                       |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | • Exécutez `kubectl config get-contexts`, déterminez le `current-context` actuel (non fonctionnel).<br/>• Trouvez le context réellement fonctionnel et basculez dessus : `kubectl config use-context <name>`. |
| Critères d'acceptation | • `current-context` == `cluster1-admin@cluster1`.<br/>• Depuis ce context, une requête vers l'API server passe réellement (il ne suffit pas qu'il existe dans le fichier). |
|        Vérification        | `kubectl config current-context`, puis `kubectl get nodes` - doit renvoyer la vraie liste des nœuds, et non une connection error. |

---

|           **2**           | **Client certificate extraction**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Ce qu'on fait       | • Extrayez le `client-certificate-data` de l'utilisateur `cluster9-admin` du kubeconfig, décodez le base64 et analysez le certificat via `openssl x509`.<br/>• Enregistrez le résultat dans `/var/work/tests/artifacts/task2-cert.txt` au format `KEY=VALUE`, une valeur par ligne : `SHA256_FP`, `SUBJECT`, `ISSUER`, `NOTBEFORE`, `NOTAFTER`. |
| Critères d'acceptation | • Les cinq valeurs dans l'artefact coïncident avec ce qui est extrait du certificat bootstrap d'origine `cluster9-admin`.<br/>• Le checker compare le fingerprint d'origine, l'immuabilité du certificat dans le kubeconfig et les cinq champs. |
|        Vérification        | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` affiche `sha256 Fingerprint=AA:BB:...` - dans l'artefact, enregistrez le hex sans deux-points (la casse n'a pas d'importance). |

---

|           **3**           | **Baseline: NodePort exposure**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Ce qu'on fait       | • Créez le namespace `cks-114`.<br/>• Créez le Deployment `backend` (par exemple `viktoruj/ping_pong:alpine` avec `SRV_PORT=80`, label `app=backend`).<br/>• Créez le Service `kubernetes-public` de type `NodePort` sur le port 80, avec un `nodePort: 30114` explicite.<br/>• **Ne touchez pas** au Service `default/kubernetes`. |
| Critères d'acceptation | • Le backend est réellement accessible à la fois depuis le nœud lui-même via `<node-internal-ip>:30114`, et à l'intérieur du cluster via `kubernetes-public.cks-114.svc.cluster.local`.<br/>• `default/kubernetes` reste `ClusterIP`.<br/>• La tâche 4 transforme ensuite ce même Service en `ClusterIP`, donc à la fin du lab, l'état NodePort n'est plus observable : la phase NodePort historique est confirmée par deux probes HTTP 200 (depuis le worker et via DNS depuis un Pod), par la vérification du backend/EndpointSlice et par un moniteur qui conserve les UID du Service et du Deployment.<br/>• Exécutez d'abord entièrement la tâche 3 et attendez le fichier `/var/lib/cks-lab114-checker/nodeport-phase-seen`, que le moniteur crée après les deux live-probes réussies ; ce n'est qu'ensuite que vous exécutez la tâche 4. Le fichier est la confirmation de la phase historique pour le même Service/Deployment. |
|        Vérification        | Depuis le worker (hors du cluster) : `curl http://<node-internal-ip>:30114/` -> HTTP 200.<br/>Depuis l'intérieur du cluster (Pod temporaire avec curl) : `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200. IP du nœud : `kubectl get nodes -o wide`. |

---

|           **4**           | **Reduce exposure: NodePort -> ClusterIP**                                                                                                                                                                       |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Ce qu'on fait       | • Changez `kubernetes-public` en type `ClusterIP`.<br/>• Souvenez-vous : l'API server ne permettra pas de laisser `nodePort` avec le type `ClusterIP` - il faut retirer explicitement le champ (`kubectl edit svc kubernetes-public` et supprimez la ligne `nodePort`, ou `kubectl patch` avec `$patch: replace` sur le tableau `ports`). |
| Critères d'acceptation | • Le chemin externe `<node-internal-ip>:30114` est maintenant bloqué au niveau transport (connection refused/timeout).<br/>• Le chemin intra-cluster fonctionne toujours.<br/>• Le Pod backend reste Ready. |
|        Vérification        | Depuis le worker : `curl -m5 http://<node-internal-ip>:30114/` -> erreur de connexion (pas un code HTTP).<br/>Depuis l'intérieur du cluster : `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200 comme avant.<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`, aucun port n'a de `nodePort`. |

## Vérification

```bash
check_result
```

Le checker vérifie le `current-context` et une requête live vers l'API via celui-ci, extrait et analyse indépendamment
le certificat `cluster9-admin`, le vérifie par rapport au bootstrap fingerprint d'origine et le compare à votre artefact, et exécute aussi un HTTP 200 probe externe et intra-cluster, vérifie le Deployment, l'EndpointSlice et l'immuabilité de `default/kubernetes`. La phase NodePort historique est confirmée par un moniteur root-owned avec deux live-probes avant le basculement du Service ; à l'état ClusterIP, le checker vérifie le DNS live et le refus transport du NodePort.

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD).

## Suppression

```bash
TASK=114 make delete_cks_task
```
