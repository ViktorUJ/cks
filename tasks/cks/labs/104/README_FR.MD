[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 104 - Restriction de l'accès à la Kubernetes API : RBAC, ServiceAccount et anonymous-auth

## Objectif

Dans ce lab CKS, vous allez restreindre l'accès à la Kubernetes API selon le principe du moindre
privilège. La pratique couvre un RBAC namespaced minimal, les tokens de
ServiceAccount modernes à courte durée de vie, un Pod sans API-token, la suppression des permissions
excessives obsolètes et la désactivation de l'accès anonyme à l'API server.

Travaillez uniquement avec les objets indiqués dans les tâches. Le namespace `security-104` et
le binding volontairement dangereux `legacy-operator-admin` ont déjà été préparés par le script de démarrage, tout comme
les fixtures des tâches 10-12 : le Secret `legacy-config`, les namespaces `rbac-a`/`rbac-b` et le
namespace `development`. C'est une configuration pédagogique, et non un exemple pour la production.

## Threat model

Supposons qu'un attaquant exécute déjà du code dans un Pod et tente d'utiliser l'identity du workload ou l'absence d'authentication pour progresser vers la Kubernetes API. Dans ce cas, ce n'est pas seulement l'accès initial qui compte, mais aussi le blast radius après le compromise.

La tâche 1 ferme un RBAC scope excessif, la tâche 2 - un token de longue durée, et la tâche 3 - un accès inutile à l'API depuis un Pod. Cela réduit les possibilités d'utiliser l'identity du workload après le compromise.

La tâche 4 supprime les permissions wildcard cluster-wide, et la tâche 5 - l'anonymous access. Chacun de ces chemins peut, pris séparément, étendre le blast radius jusqu'à la Kubernetes API.

La tâche 6 ferme un chemin de fuite distinct : un secret transmis via une environment variable devient une partie de l'environnement du processus et peut être lu depuis `/proc/1/environ` par n'importe quel processus ayant accès à `exec` dans le conteneur, et peut aussi finir dans les application logs, un crash dump ou une autre sortie de diagnostic si le programme lui-même ou l'outil de diagnostic imprime l'environnement. `kubectl describe pod` pour `env` avec `secretKeyRef` n'affiche que la référence au Secret et sa clé (`<set to the key ... in secret ...>`), et pour `envFrom` avec `secretRef`, seulement le nom du Secret, et non la valeur résolue - ne confondez pas cette référence avec une fuite de la valeur elle-même. Un volume mount avec `defaultMode: 0400` n'élimine pas l'accès du processus autorisé du conteneur à la valeur, mais retire le secret de l'environnement du processus et limite les droits de fichier en lecture au seul propriétaire.

La tâche 7 ferme les chemins cachés de RBAC privilege escalation : `impersonate`, `bind`/`escalate` et la CSR approval n'étendent pas directement la liste des ressources disponibles, mais permettent d'agir au nom d'autrui ou de se délivrer soi-même des droits plus larges - c'est une catégorie de risque distincte du wildcard `*` de la tâche 4. La tâche 8 met en place une protection systémique, et non ponctuelle : l'automount au niveau du namespace/default SA fonctionne même pour un Pod pour lequel le développeur a oublié de désactiver explicitement le token.

La tâche 9 montre que la prévention (tâches 1-8) et la détection sont des couches différentes et complémentaires. Même si les chemins d'escalade précis sont fermés dans la tâche 7, pour un futur incident il faut un moyen de voir un **changement RBAC dangereux** (par exemple, une attribution erronée ou malveillante de `cluster-admin` à quelqu'un) sans `kubectl get` manuel permanent : l'audit log fournit une forensic evidence reproductible sur qui a précisément initié le changement, et pas seulement un instantané de l'état actuel de RBAC.

ATT&CK T1528 (Steal Application Access Token) et T1613 donnent le contexte de ce scénario : les tâches ne modélisent pas une attaque distincte, mais limitent les conséquences d'un workload déjà compromis.

Les tâches 10-12 couvrent trois workflows de base, fréquents à l'examen, et non de nouvelles menaces : la tâche 10 - réutilisation sûre d'un secret existant sans hardcoder au cas par cas les valeurs dans les manifests ; la tâche 11 - réparation ponctuelle d'un Role excessif et mise en place d'un RBAC-binding cross-namespace correct, où il est facile de se tromper de scope ; la tâche 12 - onboarding complet d'un nouvel utilisateur par certificat, de la private key à l'accès vérifiable, et pas seulement l'analyse d'un kubeconfig déjà prêt.

## Testez-vous avant de commencer

Avant d'ouvrir `check_result`, assurez-vous de pouvoir répondre avec assurance à ces questions. Sinon, revenez au [chapitre 10](../../course/10/fr.md) (RBAC), au [chapitre 11](../../course/11/fr.md) (ServiceAccounts) et au [chapitre 12](../../course/12/fr.md) (restriction de l'accès à l'API).

<details>
<summary>1. En quoi `Role`+`RoleBinding` diffèrent-ils de `ClusterRole`+`ClusterRoleBinding` dans le contexte de la tâche 1 ?</summary>

`Role` n'agit que dans un seul namespace, mais son `RoleBinding` PEUT référencer un sujet (par exemple un ServiceAccount) de N'IMPORTE QUEL autre namespace - Kubernetes prend officiellement en charge un `subjects[].namespace` différent du namespace du `RoleBinding` lui-même. Ce qui reste fixe, c'est le SCOPE des droits accordés : les droits n'agissent que dans le namespace où le `RoleBinding` a été créé, indépendamment de l'origine du sujet. `RoleBinding` peut aussi référencer un `ClusterRole` (et pas seulement un `Role`) - dans ce cas, on obtient les droits d'un modèle cluster-wide, mais accordés uniquement dans le namespace du `RoleBinding` en question. `ClusterRole`+`ClusterRoleBinding` donne l'accès à tout le cluster. La tâche 1 exige un accès **namespaced** minimal, donc `Role`, et non `ClusterRole` - sinon le scope est plus large que nécessaire.
</details>

<details>
<summary>2. Pourquoi un bound projected token (tâche 2) est-il considéré comme plus sûr qu'un legacy Secret-based token ?</summary>

Un bound projected token est de courte durée (défini par `expirationSeconds`), expire automatiquement et est renouvelé par le kubelet, et est lié à un Pod précis - à la suppression du Pod, le token devient invalide. Un legacy Secret-token n'a pas d'expiration, est stocké comme un `Secret` ordinaire dans etcd et reste valide indéfiniment, même si le Pod n'existe plus.
</details>

<details>
<summary>3. Quelle est la différence entre ce que donne `automountServiceAccountToken: false` au niveau du Pod et au niveau du ServiceAccount ?</summary>

Au niveau du ServiceAccount, c'est un baseline : la valeur s'applique à tous les Pod utilisant ce SA, si le Pod ne la redéfinit pas explicitement. Au niveau du Pod, c'est un override : le champ explicite dans le Pod spec a la priorité sur la valeur du SA. La tâche 8 vérifie spécifiquement le baseline au niveau SA/namespace, et les tâches 2-3 - la configuration explicite au niveau d'un Pod donné.
</details>

<details>
<summary>4. Pourquoi `impersonate`/`bind`/`escalate` (tâche 7) n'entrent-ils pas dans la même classe de risque que le wildcard `*` (tâche 4) ?</summary>

Le wildcard `*` dans `resources`/`verbs` étend directement la **liste des opérations et des ressources disponibles**. `impersonate`/`bind`/`escalate` ne donnent pas accès à de nouvelles ressources par eux-mêmes - ils donnent la possibilité d'**agir au nom d'autrui** (`impersonate`) ou de **se délivrer soi-même des droits que l'on n'avait pas à l'origine** (`bind`/`escalate`). C'est une catégorie distincte de privilege escalation, facile à manquer lors d'un audit RBAC si l'on ne regarde que `verbs`/`resources` sans tenir compte de ces trois verbes particuliers.
</details>

## Infrastructure

L'environnement est déployé via Terragrunt dans AWS `eu-central-1` :

| Composant | Rôle |
|---|---|
| `vpc` | VPC `10.10.0.0/16` avec des sous-réseaux publics |
| `ssh-keys` | clés pour l'accès aux nœuds |
| `k8s-1` | cluster kubeadm mono-nœud avec Kubernetes `1.36.0`, containerd et **Calico** |
| `worker` | machine de travail avec `kubectl` configuré et `check_result` |

Le control-plane autorise l'exécution de Pods ordinaires, un nœud worker distinct n'est donc pas nécessaire.
Pour la tâche 5, un accès SSH au control-plane sera nécessaire : c'est là que se trouve le manifest
du static Pod de l'API server.

## Déploiement

```bash
TASK=104 make run_cks_task
```

Connectez-vous en SSH à la machine de travail. Le contexte `cluster1-admin@cluster1` est déjà configuré.

```bash
time_left
check_result
```

## Tâches

---
| **1** | **RBAC minimal pour lire les Pods** |
| :---: | :--- |
| Ce qu'on fait | Dans le namespace `security-104`, créez un ServiceAccount `auditor`, un Role `pod-observer` et un RoleBinding `auditor-pod-observer`. Le Role doit autoriser **uniquement** `get`, `list`, `watch` de la ressource `pods` de la core API. Liez-le uniquement au ServiceAccount `auditor`. |
| Critères d'acceptation | Le Role contient exactement une règle pour `pods` avec les verbes `get`, `list`, `watch` ; le RoleBinding référence ce Role et le ServiceAccount `auditor` ; au nom de `auditor`, on ne peut pas supprimer de `secrets`. |

<details>
<summary>💡 Indice pour la tâche 1</summary>

Une erreur fréquente est d'ajouter des verbes superflus (par exemple, `create` « au cas où ») ou d'utiliser `ClusterRole` au lieu de `Role`. Vérifiez par vous-même : `kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` doit renvoyer `yes`, et `kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` - `no`. Si le Role et le RoleBinding sont dans des namespaces différents, la liaison ne prendra pas effet - le `RoleBinding` doit être dans le même namespace que le `Role`, et le sujet doit y correspondre exactement par `name`/`namespace`.
</details>

---
| **2** | **Projected ServiceAccount token de courte durée** |
| :---: | :--- |
| Ce qu'on fait | Créez un ServiceAccount `api-client` et un Pod `token-client` dans `security-104`. N'utilisez pas de legacy Secret-token. Désactivez l'automontage ordinaire du token et montez le token nécessaire via **exactement une** projected `serviceAccountToken` source dans `/var/run/secrets/tokens/api-token` avec `path: api-token` et `expirationSeconds` de `600` à `3600` inclus - n'ajoutez aucune `serviceAccountToken` source supplémentaire dans le même (ou un autre) projected volume. **Ne définissez pas `audience`**, afin que le kubelet demande l'identifier de l'API server par défaut. Si l'application a besoin d'une audience distincte, comparez-la d'abord avec `--api-audiences` (ou le default de `--service-account-issuer`) sur l'API server et ne la définissez explicitement qu'ensuite. |
| Critères d'acceptation | Le Pod utilise `api-client`, a `automountServiceAccountToken: false`, et contient **exactement une** projected `serviceAccountToken` source dans toute la spécification du Pod - sans audience figée en dur, avec le path indiqué et `expirationSeconds` dans la plage `600`-`3600` (bornes incluses). Un TokenReview, exécuté depuis le contexte admin pour le token monté, renvoie `authenticated: true` et le nom `system:serviceaccount:security-104:api-client` ; une vérification RBAC distincte confirme que ce ServiceAccount ne peut pas supprimer de `secrets`. |

<details>
<summary>💡 Indice pour la tâche 2</summary>

Il n'est pas nécessaire de retenir par cœur la syntaxe exacte de `projected.sources[].serviceAccountToken` : sur `kubernetes.io/docs`, il y a un exemple tout prêt : Concepts → Storage → [Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), section **« serviceAccountToken projected volumes »**. L'erreur la plus fréquente est d'indiquer explicitement `audience: kubernetes.default.svc`, en supposant que c'est la valeur standard. Pour un cluster kubeadm, ce n'est PAS un default garanti - si vous indiquez une audience que l'API server n'accepte pas via `--api-audiences`, TokenReview renverra `authenticated: false`. N'indiquez simplement pas du tout le champ `audience` - le kubelet demandera alors l'identifier de l'API server par défaut, que le serveur accepte à coup sûr. N'oubliez pas non plus `automountServiceAccountToken: false` sur le Pod lui-même - sinon Kubernetes ajoutera un volume de token ordinaire (de style legacy) en plus de votre projected volume. Une autre erreur fréquente est de choisir un `expirationSeconds` trop petit (par exemple `300`) : la Kubernetes API exige un minimum de `600` secondes pour un `serviceAccountToken` projected volume - l'API server rejettera une valeur plus petite lors de `kubectl apply` comme invalid (`must be at least 10 minutes`).
</details>

---
| **3** | **Pod sans token de la Kubernetes API** |
| :---: | :--- |
| Ce qu'on fait | Créez un ServiceAccount `no-token-sa` avec `automountServiceAccountToken: false` et un Pod `no-token` dans `security-104` avec ce ServiceAccount. Sur le Pod lui-même, définissez aussi explicitement `automountServiceAccountToken: false`. Utilisez n'importe quelle image sûre de longue durée, par exemple `busybox:1.36` avec `sleep 3600`. Ne montez pas séparément à la main un Secret avec le token du ServiceAccount - le Pod ne doit avoir absolument aucun API-token, ni via automount ni via un legacy Secret monté explicitement. |
| Critères d'acceptation | Sur le ServiceAccount et le Pod, l'automontage est désactivé ; le Pod utilise `no-token-sa` ; dans sa spécification, il n'y a pas de volume de token de ServiceAccount ajouté automatiquement ni de Secret monté à la main du type `kubernetes.io/service-account-token` ; la tentative de lire `/var/run/secrets/kubernetes.io/serviceaccount/token` dans le conteneur se termine par une erreur (le fichier est absent), alors que `kubectl exec` lui-même doit s'exécuter avec succès. |

<details>
<summary>💡 Indice pour la tâche 3</summary>

La différence avec la tâche 8 : techniquement, il suffirait de désactiver l'automount à un seul niveau (SA ou Pod), mais la tâche exige **les deux** niveaux à la fois (defence in depth). Vérifiez par vous-même : `kubectl get pod no-token -o jsonpath='{.spec.volumes}'` ne doit rien contenir qui ressemble à `kube-api-access-*`. Si le volume est tout de même apparu - vérifiez que vous avez désactivé l'automount AVANT la création du Pod, et non après (modifier le SA n'affecte pas les Pod déjà créés). Un automount désactivé n'empêche pas de monter à la main un ancien (legacy) `Secret` avec `type: kubernetes.io/service-account-token` via `volumes[].secret` - si vous le faites, le Pod n'a formellement pas de volume automounted, mais recevra de fait tout de même un API-token valide. La tâche exige l'absence totale de token, et pas seulement l'absence d'automount.
</details>

---
| **4** | **Supprimer les permissions cluster-wide excessives** |
| :---: | :--- |
| Ce qu'on fait | Dans le cluster, on a laissé volontairement le ClusterRole `legacy-operator-admin` avec des permissions wildcard et un ClusterRoleBinding de même nom pour le ServiceAccount `legacy-operator` de `security-104`. Supprimez **les deux** objets. Ne remplacez pas l'accès wildcard par un autre ClusterRole large. |
| Critères d'acceptation | `legacy-operator-admin` n'existe ni comme ClusterRole ni comme ClusterRoleBinding ; le ServiceAccount `legacy-operator` ne peut plus lire de `secrets` dans `security-104`. |

<details>
<summary>💡 Indice pour la tâche 4</summary>

Supprimer uniquement le `ClusterRoleBinding` sans supprimer le `ClusterRole` laisse dans le cluster un modèle dangereux - quelqu'un peut créer plus tard un nouveau binding vers lui. Supprimez les deux objets. Vérifiez par vous-même avec deux commandes distinctes : `kubectl get clusterrole legacy-operator-admin` et `kubectl get clusterrolebinding legacy-operator-admin` - les deux doivent renvoyer `NotFound`.
</details>

---
| **5** | **Désactiver l'anonymous access à l'API server** |
| :---: | :--- |
| Ce qu'on fait | • Créez sur le control-plane le fichier `/etc/kubernetes/authentication-config.yaml` avec un `AuthenticationConfiguration` qui désactive l'anonymous access à tous les endpoints, sauf `/livez`, `/readyz` et `/healthz` - `/livez` et `/readyz` sont les chemins que kubeadm utilise pour les HTTPS liveness/readiness/startup probes du static Pod de l'API server (`/healthz` est conservé pour la compatibilité), et un `--anonymous-auth=false` complet casse les probes elles-mêmes, et pas seulement l'accès de l'attaquant.<br/>• Branchez le fichier via un `hostPath` volume et l'argument `--authentication-config=<chemin-dans-le-conteneur>` dans `/etc/kubernetes/manifests/kube-apiserver.yaml`, et **supprimez** le `--anonymous-auth=true` existant - les deux façons de configurer l'anonymous access s'excluent mutuellement, et kube-apiserver ne démarrera pas si les deux sont indiqués. Le kubelet redémarrera le static Pod automatiquement.<br/>• Attendez que l'API server soit prêt (le Pod reste Running/Ready) et assurez-vous qu'une requête non authentifiée vers `/version` reçoit `401`, et vers `/livez` et `/readyz` - `200`.<br/>• Vérifiez en plus que l'`--authorization-mode` effectif contient `Node,RBAC` et **ne** contient **pas** `AlwaysAllow` (une authentication sans authorization restrictive n'a aucun sens).<br/>• Auditez les ClusterRoleBinding dont les subjects sont `system:anonymous`/le groupe `system:unauthenticated` : dans le cluster, on a laissé volontairement un binding dangereux (lab-owned) de ce type, `lab104-unintended-anonymous-access` ; supprimez-le avec son ClusterRole. **Ne touchez pas** au binding standard de kubeadm `system:public-info-viewer` - il est lui aussi lié à `system:unauthenticated`, mais ne donne accès qu'aux non-resource URL `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`, c'est une partie normale du bootstrap (default Kubernetes RBAC), et non un constat (finding) pour cette tâche.<br/>• C'est une couche distincte de l'`AuthenticationConfiguration` de cette même tâche : `anonymous.conditions` y autorise volontairement l'identity anonyme uniquement sur `/livez`/`/readyz`/`/healthz` - `/version` n'est pas accessible anonymement précisément parce que la requête vers lui ne reçoit pas du tout d'anonymous identity à l'étape d'authentication, et on n'arrive pas à l'authorization via `system:public-info-viewer`, même avec cette liste plus large de non-resource URL. |
| Critères d'acceptation | • Le static Pod de l'API server utilise `--authentication-config`, qui pointe vers un `AuthenticationConfiguration` avec `anonymous.enabled: true` et des `conditions` incluant exactement `/livez`, `/readyz`, `/healthz`.<br/>• L'argument `--anonymous-auth` est absent.<br/>• Le Pod kube-apiserver reste `Running`/`Ready` après le redémarrage.<br/>• Un `GET /version` non authentifié renvoie `401`.<br/>• Les `GET /livez` et `GET /readyz` non authentifiés renvoient `200`.<br/>• Une requête authentifiée vers `/readyz` (avec des credentials valides) fonctionne aussi.<br/>• L'`--authorization-mode` effectif contient `Node,RBAC` et ne contient pas `AlwaysAllow`.<br/>• Les ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` sont supprimés.<br/>• Le `system:public-info-viewer` standard est resté intact.<br/>• Le groupe `system:unauthenticated` ne peut lire `pods`/`secrets`/`configmaps` dans aucun namespace. |

<details>
<summary>💡 Indice pour la tâche 5</summary>

Ne modifiez pas l'objet Pod via `kubectl edit pod` - le kubelet surveille le fichier de manifest et remettra à l'état d'origine toute modification faite via l'API. Modifiez précisément le fichier `/etc/kubernetes/manifests/kube-apiserver.yaml` sur le disque du nœud. Après l'enregistrement, patientez : le kubelet ne détecte pas instantanément la modification du fichier, et l'API server sera indisponible quelques secondes pendant le redémarrage du static Pod - ne paniquez pas si `curl` juste après l'enregistrement du fichier ne renvoie rien.

Un simple `--anonymous-auth=false` ne **convient pas** ici : kubeadm `release-1.36` génère le static Pod de kube-apiserver avec des HTTPS liveness/readiness/startup probes précisément sur `/livez` et `/readyz`, et les HTTP probes du kubelet ne transmettent pas de client credentials - avec l'anonymous access entièrement désactivé, ces requêtes reçoivent `401`, le kubelet considère le conteneur comme malsain et peut redémarrer kube-apiserver en boucle, ce qui casse non seulement cette tâche, mais aussi la tâche 9 suivante. La bonne voie est un `AuthenticationConfiguration` avec `anonymous.enabled: true` et des `anonymous.conditions` qui limitent l'anonymous access uniquement aux chemins health nécessaires :

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` et `--anonymous-auth` ne peuvent pas être indiqués simultanément - kube-apiserver ne démarrera pas si les deux arguments sont présents dans le manifest. Assurez-vous d'avoir supprimé `--anonymous-auth=true` complètement, et non d'avoir simplement remplacé la valeur par `false`.

Pour auditer les ClusterRoleBinding anonymes : `kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`. Vous verrez au moins DEUX
bindings - le standard `system:public-info-viewer` (n'y touchez pas) et le lab-owned
`lab104-unintended-anonymous-access` (supprimez-le avec son ClusterRole
`lab104-anonymous-debug-access`). On peut les distinguer par le nom du ClusterRole vers lequel ils
pointent : `kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` affichera `system:public-info-viewer` - c'est un ClusterRole
limité aux non-resource URL, et non aux resources ordinaires.
</details>

---
| **6** | **Fuite de Secret via env dans `/proc/1/environ` : passage à un volume** |
| :---: | :--- |
| Ce qu'on fait | • Le Pod `app-vulnerable` dans `security-104` reçoit `db-creds` via `envFrom.secretRef` - la valeur est accessible à quiconque peut faire `kubectl exec` dans le conteneur (`cat /proc/1/environ`) ou lire les logs/describe en cas d'affichage accidentel de l'env.<br/>• Confirmez cette fuite : exécutez `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` et enregistrez la sortie (avec `DB_PASSWORD`) dans `/var/work/tests/artifacts/6/env-leak-before.txt`.<br/>• Recréez le Pod avec le même nom `app-vulnerable` : supprimez `envFrom`/`env` avec ce secret, montez `db-creds` comme volume `db-creds-vol` dans `/etc/secrets` en **read-only**, avec `defaultMode: 0400`.<br/>• Confirmez l'absence de la variable `DB_PASSWORD` dans le nouveau `/proc/1/environ` et enregistrez le `stat -L -c '%a'` du fichier monté dans `/var/work/tests/artifacts/6/secret-file-mode.txt` (le flag `-L` est obligatoire - le secret est monté via une chaîne de symlinks `..data`, sans `-L`, `stat` affichera le mode du symlink lui-même, et non du fichier réel). |
| Critères d'acceptation | `env-leak-before.txt` contient la VRAIE valeur de `DB_PASSWORD` du Secret `db-creds` (pas simplement le mot `DB_PASSWORD`) ; le Pod final `app-vulnerable` n'a pas d'`env`/`envFrom` référençant `db-creds` et n'a pas de seconde façon de monter le même Secret ; le volume `db-creds-vol` est monté dans `/etc/secrets` en `readOnly: true` avec `defaultMode: 0400` (`256` décimal) - le checker vérifie lui-même `stat -L -c %a` dans le conteneur et exige exactement `400` ; `DB_PASSWORD` est absent de `/proc/1/environ` du Pod final (avec un `exec` exécuté avec succès - un `exec` échoué ne compte pas comme preuve) ; le processus de l'application peut en outre encore réellement lire la valeur du secret depuis `/etc/secrets/DB_PASSWORD` (positive control). |

<details>
<summary>💡 Indice pour la tâche 6</summary>

`/proc/1/environ` à l'étape de confirmation de la fuite n'est pas la seule façon de voir la valeur
(le même résultat sera donné par `kubectl exec ... -- env` ou `echo $DB_PASSWORD`, car
le container runtime donne par défaut au processus exec'é le même environnement qu'au PID 1).
`/proc/1/environ` lit l'environnement précisément du PID 1 directement via `/proc`, et ne s'appuie pas sur
ce qu'a hérité votre propre exec-shell - c'est la même technique qu'on utilise réellement
en analyse de sécurité pour voir l'environnement de n'importe quel processus, et pas seulement le sien.

Un volume mount **ne retire pas l'accès à celui qui a déjà `kubectl exec`** - `cat
/etc/secrets/DB_PASSWORD` après la correction lit la valeur aussi facilement que `cat
/proc/1/environ` la lisait avant la correction, et c'est attendu (le positive control de la tâche
le vérifie précisément). La tâche ne consiste pas à fermer l'accès exec - c'est impossible aussi bien pour un fichier que pour
une variable, si le processus a le droit de lire la valeur. La vraie différence est dans les chemins de
fuite qui agissent SANS `exec` explicite :
- les variables d'environnement sont héritées automatiquement par **n'importe quel** processus enfant (`fork()`
  copie tout l'env) - une bibliothèque tierce, un plugin ou un subprocess accidentel à l'intérieur de
  l'application recevra `DB_PASSWORD`, même si le développeur n'y a pas pensé ; un fichier n'est pas
  transmis ainsi - le processus enfant doit connaître explicitement le chemin et l'ouvrir ;
- les crash handlers et les error-loggers impriment souvent tout l'`environ` du processus lors du
  plantage - cela partira automatiquement dans les logs ; le contenu d'un fichier n'atteindra pas
  les logs de lui-même tant que le code ne l'a pas explicitement lu et journalisé ;
- les variables d'environnement n'ont pas de modèle de droits d'accès - elles sont vues par n'importe quel processus du namespace
  du conteneur ; un fichier avec `defaultMode: 0400` en a un - seul le processus avec l'UID voulu le lit.

```text
[FAIL] defaultMode du Secret Volume indiqué de façon incorrecte.
💡 Vous avez indiqué defaultMode: 400 (décimal 400).
   YAML prend en charge un littéral octal avec un zéro initial (0400), que Kubernetes
   interprète comme des droits Unix ordinaires ; sans zéro initial, 400 se lit comme le nombre
   décimal 400, et non comme les droits 0400 (qui valent 256 en décimal).
```

C'est l'erreur la plus fréquente de cette tâche : `defaultMode` est un champ numérique avec des POSIX mode bits, et
Kubernetes YAML prend en charge pour lui aussi bien la notation octale que décimale - contrairement
à JSON, où seule la décimale est admise. Si vous écrivez `defaultMode: 400` (sans zéro
initial), Kubernetes l'interprétera comme le **décimal** 400, et non comme les droits Unix habituels
`0400`. La bonne façon est soit d'écrire `defaultMode: 0400` (avec le zéro initial, YAML
reconnaît le littéral octal), soit d'indiquer explicitement l'équivalent décimal `256`. Vérifiez par vous-même :
`kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
doit renvoyer `256`, et `stat -L -c '%a' /etc/secrets/DB_PASSWORD` dans le conteneur - `400`.
</details>

---
| **7** | **Audit et révocation des chemins cachés de RBAC privilege escalation (`impersonate`, `bind`, `escalate`, CSR approval)** |
| :---: | :--- |
| Ce qu'on fait | • Le ClusterRole `build-agent-hidden-privesc` ne contient pas le wildcard `*` (c'est un chemin distinct, déjà éliminé dans la tâche 4), mais donne au ServiceAccount `build-agent` de `security-104` trois chemins réellement exploitables d'élévation de privilèges :<br/>• `impersonate` sur `users`/`groups`/`serviceaccounts` - usurpation d'identité, y compris cluster-admin, si un tel utilisateur est connu de l'attaquant.<br/>• `create`/`update`/`bind`/`escalate` sur `clusterroles` et `create`/`update` sur `clusterrolebindings` - les verbs de base permettent de créer/modifier les objets eux-mêmes, et `bind`/`escalate` contournent la vérification RBAC intégrée, qui interdirait autrement de délivrer/lier des droits plus larges que les siens (sans les `create`/`update` de base, `bind`/`escalate` seuls ne suffisent pas pour une réelle escalade).<br/>• `update` sur `certificatesigningrequests/approval` + `approve` sur le signer `kubernetes.io/kube-apiserver-client` - la possibilité d'approuver un CSR avec une identity arbitraire (mais ce ClusterRole en lui-même ne donne pas `create certificatesigningrequests` : pour mener l'attaque jusqu'à l'émission d'un certificat, l'identity a aussi besoin d'une possibilité distincte de créer un CSR, par exemple via un autre rôle compromis ou une compromised automation qui sait déjà envoyer des CSR).<br/>• Trouvez **tous** les ClusterRoleBinding dont les ClusterRole autorisent `impersonate`, `bind` ou `escalate` (par exemple, via `kubectl get clusterrole -o json \| jq` sur `rules[].verbs`), notez-les dans `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`.<br/>• Supprimez le ClusterRoleBinding `build-agent-hidden-privesc` **et** le ClusterRole `build-agent-hidden-privesc` (et, si vous en trouvez d'autres non intentionnels, eux aussi, mais pas les ClusterRoleBinding système `system:*`).<br/>• Confirmez la révocation via `kubectl auth can-i` pour TOUS les droits trouvés : `impersonate users`, `bind clusterroles`, `escalate clusterroles`, `update certificatesigningrequests/approval`, ainsi que `approve` sur le signer `kubernetes.io/kube-apiserver-client` - tous doivent renvoyer `no`. |
| Critères d'acceptation | • `dangerous-bindings-before.txt` contient `build-agent-hidden-privesc` parmi ceux trouvés comme ClusterRoleBinding (et non le nom du ClusterRole, s'ils ne coïncident pas).<br/>• Le ClusterRoleBinding **et** le ClusterRole `build-agent-hidden-privesc` n'existent pas après la correction.<br/>• `build-agent` ne peut pas `impersonate`, `bind`, `escalate`, `update certificatesigningrequests/approval`.<br/>• `build-agent` ne peut pas exécuter `approve` sur le signer `kubernetes.io/kube-apiserver-client`.<br/>• Les ClusterRoleBinding système `system:*` n'ont pas été touchés. |

<details>
<summary>💡 Indice pour la tâche 7</summary>

La CSR approval est une catégorie distincte de `impersonate`/`bind`/`escalate` : elle n'entre pas dans le même filtre `jq` sur les `verbs`, car il s'agit d'une règle distincte sur la ressource `certificatesigningrequests/approval` avec le verb `update`, plus `approve` sur un `signer` précis. Si vous filtrez uniquement sur `impersonate`/`bind`/`escalate`, vous trouverez un chemin, mais vous manquerez le CSR - cherchez les deux séparément, et pour chacun, enregistrez précisément le nom du **ClusterRoleBinding**, et non du ClusterRole auquel il se réfère (dans ce lab, les noms coïncident, mais en général ce n'est pas garanti). Ne supprimez pas les `ClusterRoleBinding` système avec le préfixe `system:` - ils sont nécessaires aux composants core de Kubernetes pour un `impersonate` légitime (par exemple, `system:kube-controller-manager`).
</details>

---
| **8** | **Baseline au niveau du namespace : ServiceAccount `default` sans automount** |
| :---: | :--- |
| Ce qu'on fait | • La tâche 3 désactivait l'automount de façon ponctuelle, à l'intérieur d'un Pod précis et de son propre ServiceAccount. Ici, il faut un baseline au niveau du **namespace**.<br/>• Créez le namespace `security-104-baseline`, attendez l'apparition du ServiceAccount `default` créé automatiquement (la création du ServiceAccount se fait de façon asynchrone par un controller distinct, et non en même temps que le namespace lui-même).<br/>• Ce n'est qu'ensuite que vous définissez `automountServiceAccountToken: false` sur ce ServiceAccount : `kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`.<br/>• Créez dans ce namespace un Pod `implicit-default-sa` à partir de `busybox:1.36` (`sleep 3600`), **sans indiquer** explicitement ni `serviceAccountName` ni `automountServiceAccountToken` - il doit utiliser implicitement le SA `default` et hériter de sa valeur.<br/>• Confirmez que dans la spécification du Pod final le champ `automountServiceAccountToken` est absent (et non égal à `false`), qu'il n'y a pas de volume de token, et que la tentative de lire le fichier de token dans le conteneur se termine précisément par une erreur d'absence du fichier (`kubectl exec` lui-même doit alors s'exécuter avec succès). |
| Critères d'acceptation | • Le ServiceAccount `default` dans `security-104-baseline` a `automountServiceAccountToken: false`.<br/>• Le Pod `implicit-default-sa` utilise `serviceAccountName: default` (implicitement ou explicitement).<br/>• Dans sa spécification, le champ `automountServiceAccountToken` est **absent** (non défini explicitement ni à `true` ni à `false`).<br/>• Il n'y a pas de volume `projected`/`secret` avec le token du ServiceAccount ajouté automatiquement ni de legacy `Secret` monté à la main du type `kubernetes.io/service-account-token`.<br/>• `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` se termine avec succès (exit code `0`), confirmant l'absence du fichier précisément via un exec réussi, et non via une erreur arbitraire. |

<details>
<summary>💡 Indice pour la tâche 8</summary>

L'ordre des opérations est critique : si vous créez le Pod AVANT que le `patch` ne soit appliqué au SA `default` du namespace, le Pod recevra le token selon l'ancienne valeur (default `true`). Ne patchez pas non plus le SA `default` IMMÉDIATEMENT après `kubectl create namespace` sans vérifier - le ServiceAccount `default` est créé par un controller distinct et peut ne pas encore exister dans les premières fractions de seconde après la création du namespace ; attendez son apparition (`kubectl get serviceaccount default -n security-104-baseline`), et ne patchez qu'ensuite. La tâche n'indique volontairement pas `serviceAccountName` dans le Pod - cela modélise la situation réelle où le développeur a simplement oublié le ServiceAccount, et le baseline doit le protéger par défaut. Un `automountServiceAccountToken: false` explicite SUR LE POD LUI-MÊME ne démontrerait qu'une configuration ponctuelle (comme dans la tâche 3) - ici, il faut laisser le champ complètement non indiqué, pour démontrer précisément l'héritage depuis le SA/namespace.
</details>

---
| **9** | **Tâche d'intégration : détecter une escalade RBAC via l'audit log et la contenir** |
| :---: | :--- |
| Ce qu'on fait | • Cette tâche combine RBAC (ce lab) avec l'audit-logging (voir le [chapitre 32](../../course/32/fr.md)) - sans audit log, le fait même d'un changement RBAC dangereux ne serait visible que post-hoc via `kubectl get`, et non comme une forensic evidence reproductible.<br/>• Sur le control-plane, activez un audit backend minimal : créez `/etc/kubernetes/audit/policy.yaml` avec une règle `RequestResponse` pour `apiGroups: ["rbac.authorization.k8s.io"]`, les ressources `clusterroles` et `clusterrolebindings`, et un catch-all `Metadata` comme fallback.<br/>• Dans le static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml`, ajoutez `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` et les hostPath volume/volumeMount nécessaires (créez les répertoires à l'avance). Attendez le rétablissement de l'API.<br/>• Au nom de l'administrateur (`cluster1-admin`), créez le ClusterRoleBinding `incident-simulated-escalation`, liant le ClusterRole `cluster-admin` au ServiceAccount `build-agent` de `security-104` - ce n'est **pas** une tentative d'escalade de la part de `build-agent` lui-même (la tâche 7 lui a déjà révoqué les chemins réels d'élévation de privilèges), mais un changement RBAC dangereux modélisé par l'administrateur : un scénario réel où quelqu'un (un opérateur humain, un script, un CI/CD compromis) délivre par erreur ou de manière malveillante `cluster-admin` à un ServiceAccount, et la tâche de l'ingénieur SOC/security est de détecter précisément un tel événement via l'audit log, et non via un `kubectl get` manuel permanent.<br/>• Trouvez dans l'audit log l'événement `create` pour `clusterrolebindings` avec ce nom, avec `requestObject.roleRef` vers `cluster-admin` et `system:serviceaccount:security-104:build-agent` dans `requestObject.subjects`, enregistrez l'événement en entier (y compris `user.username` - de celui qui a réellement initié la requête) dans `/var/work/tests/artifacts/9/audit-escalation-event.json`. Il ne s'agit pas seulement de « s'assurer que la règle d'audit fonctionne » - la vraie tâche de l'ingénieur SOC ici est précisément d'**extraire et enregistrer une entrée précise** comme forensic evidence (le checker lit lui-même et indépendamment l'`audit.log` sur le control-plane et compare l'`auditID` de votre artefact avec l'entrée réelle - un JSON inventé, même ressemblant, ne passera pas).<br/>• Effectuez le containment : supprimez `incident-simulated-escalation` et confirmez via `kubectl auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent` que l'accès est révoqué ; enregistrez le `no` final dans `/var/work/tests/artifacts/9/containment-result.txt` (`can-i` sans `-n`/`-A` ne vérifie que le namespace courant du contexte de votre kubeconfig, et non tout le cluster - indiquez le namespace explicitement). |
| Critères d'acceptation | • Le static manifest de kube-apiserver contient `--audit-policy-file` et `--audit-log-path`, l'API server est healthy.<br/>• `/var/work/tests/artifacts/9/audit-escalation-event.json` est un audit event JSON valide avec `verb: create`, `objectRef.resource: clusterrolebindings`, `objectRef.name: incident-simulated-escalation`, `requestObject.roleRef.name: cluster-admin` et le ServiceAccount `build-agent` de `security-104` parmi les `requestObject.subjects`.<br/>• Le ClusterRoleBinding `incident-simulated-escalation` n'existe pas après le containment.<br/>• `containment-result.txt` contient `no`. |

<details>
<summary>💡 Indice pour la tâche 9</summary>

La règle `RequestResponse` pour `rbac.authorization.k8s.io` doit se trouver EN PREMIER dans la liste des règles de la policy - la règle plus spécifique doit précéder le catch-all général `Metadata`, sinon le catch-all interceptera l'événement plus tôt et vous n'obtiendrez que le niveau `Metadata` au lieu de `RequestResponse` avec le corps de la requête. Ajoutez `omitStages: [RequestReceived]` au niveau de toute la policy - cette étape n'a pas encore de `requestObject`/`responseStatus`, et le catch-all `Metadata` s'applique à absolument toutes les requêtes du cluster, de sorte que sans `omitStages` l'`audit.log` grossit deux fois plus vite sans aucun avantage supplémentaire pour cette tâche. Créez `incident-simulated-escalation` APRÈS le redémarrage de l'API server avec le nouvel audit backend - sinon l'événement n'arrivera simplement pas dans le log. Cette tâche vérifie la détection du changement RBAC dangereux per se, et non le fait que précisément `build-agent` l'ait effectué - dans l'audit log, le champ `user.username` montrera l'initiateur réel (l'administrateur), et non `build-agent` ; `build-agent` figure dans cet événement uniquement comme destinataire des droits (`requestObject.subjects`). `audit-escalation-event.json` doit être une entrée **réelle**, copiée de `/var/log/kubernetes/audit/audit.log` (y compris son `auditID`) - un JSON assemblé à la main avec quelques lignes correspondantes ne passera pas la vérification, car le self-check lit lui-même le log sur le control-plane et compare l'`auditID`. N'oubliez pas le containment : supprimer le `ClusterRoleBinding` en lui-même n'est que la moitié de la tâche, l'autre moitié consiste à démontrer via `kubectl auth can-i` que l'accès est réellement révoqué, et pas simplement que l'objet est devenu illisible.
</details>

---
| **10** | **Décodage, création et montage d'un Secret** |
| :---: | :--- |
| Ce qu'on fait | • Dans `security-104` existe déjà un Secret Opaque `legacy-config` avec deux clés : `SERVICE_USER` et `SERVICE_TOKEN`. Lisez-le via l'API et décodez les deux valeurs depuis le base64.<br/>• Créez un nouveau Secret generic `rehydrated-config` à partir de valeurs literal (`kubectl create secret generic ... --from-literal=...`), avec LES MÊMES noms de clés et LES MÊMES valeurs décodées.<br/>• Créez un Pod `secret-workflow` à partir de `busybox:1.36` (`sleep 3600`) qui monte `rehydrated-config` comme volume **read-only** dans `/etc/rehydrated`.<br/>• Confirmez que les deux fichiers dans le conteneur sont réellement lisibles et contiennent les valeurs attendues. |
| Critères d'acceptation | • `rehydrated-config` existe et ses `SERVICE_USER`/`SERVICE_TOKEN` décodés coïncident avec ceux du `legacy-config` d'origine.<br/>• Le Pod `secret-workflow` monte précisément ce Secret dans `/etc/rehydrated` avec `readOnly: true`.<br/>• `kubectl exec` dans le conteneur lit les deux fichiers avec le contenu correct. |

<details>
<summary>💡 Indice pour la tâche 10</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' | base64 -d` vous donne
la valeur réelle - n'écrivez pas une chaîne arbitraire dans le nouveau Secret, le checker
redécode lui-même l'original et compare. `kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` encode les valeurs
automatiquement - il n'est pas nécessaire de faire soi-même un base64-encode lors de la création via `--from-literal`.
N'oubliez pas `readOnly: true` sur le volumeMount - un Secret monté, mais writable, ne
passe pas le critère d'acceptation littéralement par le flag, même si le Pod lui-même fonctionne correctement.
</details>

---
| **11** | **Réparation du Role existant et liaison à un SA d'un autre namespace** |
| :---: | :--- |
| Ce qu'on fait | • Dans le namespace `rbac-a` existent déjà le ServiceAccount `dev`, le Role `pod-role` et le RoleBinding `pod-role-binding`. Le Role autorise actuellement `get`, `list`, `delete` sur `pods` - `delete` est ici superflu (retirez-le), et `watch` est absent, alors qu'il est nécessaire (ajoutez-le). Corrigez précisément le Role existant, n'en créez pas un nouveau.<br/>• Séparément, dans le namespace `rbac-b` existe déjà le ConfigMap `shared-config`. Créez dans `rbac-b` un nouveau Role et RoleBinding donnant au ServiceAccount `dev` **du namespace `rbac-a`** l'accès `get`/`list` (et uniquement celui-ci) sur `configmaps` dans `rbac-b`.<br/>• Créez un Pod dans `rbac-a` avec `serviceAccountName: dev`. |
| Critères d'acceptation | • Le Role `pod-role` dans `rbac-a` autorise exactement `get`, `list`, `watch` sur `pods`.<br/>• `dev` ne peut pas `delete pods` dans `rbac-a`.<br/>• `dev` peut `get`/`list configmaps` dans `rbac-b`, mais ne peut pas `delete configmaps` et ne peut pas lire `secrets` au même endroit.<br/>• Dans `rbac-a` existe un Pod utilisant le ServiceAccount `dev`. |

<details>
<summary>💡 Indice pour la tâche 11</summary>

`RoleBinding` peut référencer un sujet (`ServiceAccount`) de N'IMPORTE QUEL autre namespace -
Kubernetes le prend officiellement en charge via `subjects[].namespace`. Mais le `RoleBinding` lui-même,
et les droits qui lui sont associés, n'agissent toujours que dans le namespace où IL a été créé LUI-MÊME - c'est pourquoi
le nouveau Role+RoleBinding doit être créé précisément DANS `rbac-b`, et non dans `rbac-a`. Vérifiez par vous-même :
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` doit
renvoyer `yes`, et `kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` -
`no`.
</details>

---
| **12** | **Utilisateur avec certificat client via CSR + namespaced RBAC** |
| :---: | :--- |
| Ce qu'on fait | • Créez un nouvel utilisateur Kubernetes `john`, authentifié par un certificat client : générez une private key, puis un CSR (`openssl req -new`) avec `CN=john`.<br/>• Envoyez-le comme `CertificateSigningRequest` Kubernetes `john-csr` avec `signerName: kubernetes.io/kube-apiserver-client` ; approuvez le CSR (`kubectl certificate approve`).<br/>• Extrayez le certificat émis de `status.certificate` (base64-decode) et enregistrez-le avec la private key dans `/var/work/tests/artifacts/12/john.crt` et `.../john.key`.<br/>• Dans le namespace `development` (déjà créé), créez un Role autorisant `create`/`list`/`get` sur `pods`, et un RoleBinding sur le subject `{kind: User, name: john}`.<br/>• Constituez pour John un kubeconfig distinct (`kubectl config set-cluster`/`set-credentials --client-certificate/--client-key`/`set-context`) et enregistrez-le comme `/var/work/tests/artifacts/12/john.kubeconfig` ; assurez-vous que `kubectl --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development` fonctionne réellement, et que la même requête vers un autre namespace reçoit `Forbidden` - cela démontre que le certificat est opérationnel, tout comme une requête TLS directe, mais via le `kubectl` habituel, et non `curl`.<br/>• Confirmez par des vérifications `kubectl auth can-i --as=john` en direct : John peut `create`/`list`/`get` des pods dans `development`, ne peut pas les `delete` au même endroit et n'a pas les mêmes droits dans un autre namespace. |
| Critères d'acceptation | • `john-csr` utilise le bon signer et est `Approved`.<br/>• Le certificat émis a `CN=john` et se vérifie réellement contre la CA de ce cluster.<br/>• Role+RoleBinding dans `development` donnent à John exactement `create`/`list`/`get` sur `pods`.<br/>• John ne peut pas `delete` de pods au même endroit et n'a pas accès aux autres namespaces.<br/>• Les `john.crt`/`john.key` enregistrés sont réellement acceptés par l'API server lors d'une requête TLS directe (et pas seulement via l'impersonation `--as=john`).<br/>• Le kubeconfig constitué existe au chemin `/var/work/tests/artifacts/12/john.kubeconfig`, et `kubectl --kubeconfig=<ce fichier> get pods -n development` fonctionne réellement, tandis que la même requête vers un autre namespace se termine par `Forbidden`. |

<details>
<summary>💡 Indice pour la tâche 12</summary>

Ne confondez pas cette tâche avec le lab 114 : là-bas, vous analysez un certificat DÉJÀ existant du
kubeconfig, et ici il faut émettre de zéro une identity entièrement nouvelle et réellement opérationnelle.
Le RBAC pour un utilisateur basé sur certificat se lie via `subjects: [{kind: User, name:
john}]`, et non `ServiceAccount` - `User` dans Kubernetes n'a pas d'objet d'API distinct, son
« existence » est entièrement déterminée par le fait que le CN dans le certificat client coïncide avec
le `name` dans le binding. `--as=john` dans `kubectl auth can-i` ne vérifie que la logique RBAC
(impersonation), mais ne démontre pas que le certificat est réellement valide - assurez-vous séparément
que `openssl verify` contre `/etc/kubernetes/pki/ca.crt` sur le control-plane renvoie `OK`.
</details>

## Vérification

Sur la machine de travail, exécutez :

```bash
check_result
```

La vérification contient Init et douze tâches indépendantes. Après la modification de l'API server,
certains tests peuvent attendre brièvement le redémarrage du static Pod.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD)

## Suppression

```bash
TASK=104 make delete_cks_task
```
