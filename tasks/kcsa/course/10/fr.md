[Русская версия](ru.md) · [Eng version](README.md) · [Versión en español](es.md) · [Deutsche Version](de.md) · [ქართული ვერსია](ge.md) · [繁體中文版](tw.md) · [日本語版](jp.md)

# Chapitre 10. Authentification et autorisation

> **Et ensuite.** Dans les chapitres 07 à 09, nous avons sécurisé les composants du cluster, les nœuds de travail, les `Pod` et les frontières réseau. Nous allons maintenant examiner le cheminement d'une requête vers l'API Kubernetes : le cluster établit d'abord l'identité, puis détermine si son action est autorisée. Cela relève du domaine KCSA **Kubernetes Security Fundamentals**, dont le poids est de 22 %.

## 10.1 Qui s'adresse à l'API : utilisateurs et `ServiceAccount`

Chaque requête vers l'API Kubernetes passe par une authentification, ou authentication. Son objectif est de répondre à la question « qui est-ce ? ». Après une authentification réussie, l'API Server transmet le nom d'utilisateur et les groupes à l'étape suivante, l'autorisation.

Un utilisateur ordinaire, par exemple un ingénieur ou un système CI extérieur au cluster, n'est pas un objet Kubernetes `User`. Kubernetes reçoit cette identité du mécanisme d'authentification configuré. Un `ServiceAccount` est un objet de l'API Kubernetes destiné avant tout aux processus dans un `Pod`. Son nom complet contient le namespace : `system:serviceaccount:shop:catalog`.

| Méthode | Quand elle s'applique | Limitation importante |
|---|---|---|
| Certificat client TLS | Administrateur, composant du cluster ou automatisation | Il faut protéger la clé privée et la durée de validité du certificat. |
| Bearer token | Automatisation ou intégration | Le token transmet les privilèges de son détenteur, il ne doit pas être placé dans du code ou des journaux. |
| Token `ServiceAccount` | Un processus à l'intérieur d'un `Pod` appelle l'API | Les droits sont déterminés par RBAC, et non par le seul fait de posséder un token. |
| OIDC | Fournisseur d'identité externe, par exemple le SSO d'entreprise | L'API Server doit faire confiance à l'issuer et vérifier les claims du token. |
| Authentication webhook | Un service externe confirme le credential du client | C'est une authentication integration, et non un admission webhook ni un authorizer. |
| Bootstrap token | Token à usage limité pour le rattachement initial d'un nœud | Il est requis pour bootstrap/TLS bootstrap, pas comme application identity de longue durée. |

Une requête anonyme, lorsque l'authentification anonyme est activée, devient l'utilisateur `system:anonymous` et le groupe `system:unauthenticated`. Ce n'est pas un mode pratique pour l'accès habituel à l'API. Dans une configuration sécurisée, l'accès anonyme est désactivé ou ne reçoit que des endpoints volontairement ouverts et sûrs.

L'authentification ne donne pas elle-même accès. Un certificat, un token ou une identité OIDC ne fait que nommer le sujet. L'autorisation détermine ce que ce sujet peut faire.

## 10.2 Tokens `ServiceAccount` et risque du compte `default`

Chaque `Namespace` contient un `ServiceAccount` nommé `default`. Si la spécification d'un `Pod` ne précise pas `serviceAccountName`, Kubernetes lui attribue celui-ci. Cela ne signifie pas que `default` dispose automatiquement de droits étendus : le risque apparaît lorsqu'un `RoleBinding` ou un `ClusterRoleBinding` lui a été accordé par commodité.

Kubernetes moderne, y compris v1.36, fournit généralement à un `Pod` un bound token projeté via le mécanisme TokenRequest. Un tel token est lié au `ServiceAccount` et au `Pod` concerné, a une durée de vie limitée et est automatiquement renouvelé par kubelet. Un Secret de longue durée contenant un token `ServiceAccount` ne doit pas être créé sans raison justifiée.

Si une application n'a pas besoin de l'API Kubernetes, elle n'a pas besoin d'un token. Son montage est désactivé dans le `Pod` ou dans le `ServiceAccount` lui-même :

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: web
  namespace: shop
automountServiceAccountToken: false
---
apiVersion: v1
kind: Pod
metadata:
  name: web
  namespace: shop
spec:
  serviceAccountName: web
  automountServiceAccountToken: false
  containers:
    - name: web
      image: nginx:1.30.4
```

En cas de compromission du conteneur, le token monté peut être lu et utilisé depuis l'extérieur du cluster tant qu'il est valide. Par conséquent, chaque `Pod` reçoit un `ServiceAccount` distinct avec les droits minimaux, et `default` n'est pas utilisé comme compte commun aux applications. Désactiver automount n'annule pas RBAC, mais retire le secret du système de fichiers du pod qui n'a pas besoin de l'API.

## 10.3 Autorisation : RBAC et autres authorizer

L'autorisation répond à la question « le sujet déjà authentifié peut-il effectuer cette action ? ». L'API Server évalue la combinaison de l'utilisateur ou du groupe, du `verb`, de la ressource, du namespace et, parfois, du nom de l'objet et du chemin de l'API.

Plusieurs authorizer peuvent être activés dans Kubernetes. Ils sont vérifiés dans l'ordre configuré : le premier qui renvoie `Allow` ou `Deny` termine immédiatement la décision ; ce n'est que si tous renvoient `NoOpinion` que la requête est refusée par défaut. Le mécanisme principal et recommandé pour la plupart des clusters est RBAC.

| Mécanisme | Objectif | Sens pratique |
|---|---|---|
| RBAC | Règles dans les `Role`, `ClusterRole` et bindings | Choix habituel pour un accès administré et vérifiable. |
| Node | Limite les actions de kubelet au nom d'un nœud | Utilisé pour les identités de nœud, pas à la place du RBAC des utilisateurs. |
| Webhook | Interroge un service d'autorisation externe | Convient lorsque la décision dépend d'un système externe. |
| ABAC | Compare la requête à un fichier de politiques statique | Approche obsolète pour les nouveaux projets, difficile à auditer et à maintenir. |

Ne confondez pas RBAC avec l'authentication. Un `RoleBinding` ne confirme pas une identité et ne crée pas de token. Il associe un sujet déjà connu à un ensemble d'autorisations. De même, une `NetworkPolicy` limite les connexions réseau, mais ne remplace pas la décision de l'API Server concernant les droits sur une ressource.

### Node authorizer et `NodeRestriction` : couches voisines, mais distinctes

Le **Node authorizer** est un authorizer spécial pour l'identité kubelet/node `system:node:<nodeName>` du groupe `system:nodes`. Il limite les opérations d'API que kubelet peut effectuer pour son nœud et les `Pod` qui lui sont assignés, notamment les `Secret`, `ConfigMap` et informations de volumes dont il a besoin. Il s'agit d'**authorization**.

`NodeRestriction` est un validating admission plugin. Il limite en outre les objets `Node` et les `Pod` associés que kubelet peut modifier : un kubelet correctement identifié ne doit pas modifier le Node/Pod d'autrui ni définir arbitrairement des labels protégés. Il s'agit d'**admission**, et non d'un authorizer.

> **À ne pas confondre.** Le Node authorizer répond à la question « cette node identity est-elle autorisée à effectuer cette action d'API ? ». `NodeRestriction` répond à la question « même après l'autorisation, cette modification de l'objet est-elle admissible ? ». Ces deux mécanismes sont importants pour le least privilege de kubelet, mais ils ne remplacent ni le RBAC des utilisateurs, ni TLS, ni la protection du nœud.

## 10.4 RBAC : rôles, bindings et privilèges minimaux

Un `Role` décrit des règles dans un seul `Namespace`. Un `ClusterRole` décrit des règles à l'échelle de tout le cluster ou peut être lié à un seul namespace via un `RoleBinding`. Un `RoleBinding` s'applique dans son namespace, tandis qu'un `ClusterRoleBinding` s'applique à l'ensemble du cluster.

Les autorisations RBAC sont additives : plusieurs bindings s'additionnent, et il n'existe pas de règle distincte pour « refuser ». Le principe du moindre privilège consiste donc à accorder uniquement les `apiGroups`, `resources` et `verbs` nécessaires, tout en choisissant la portée la plus réduite.

Le `Role` ci-dessous autorise l'application à lire un seul `ConfigMap` dans le namespace `shop`. C'est un exemple de règle étroite, et non un modèle pour toutes les tâches.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-site-config
  namespace: shop
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    resourceNames: ["site-config"]
    verbs: ["get"]
```

Vous pouvez vérifier une autorisation attendue avec la commande `kubectl auth can-i`. Par exemple, un administrateur peut vérifier une action pour un compte précis :

```bash
kubectl auth can-i get configmap/site-config -n shop \
  --as=system:serviceaccount:shop:web
```

Cette commande est utile pour vérifier, mais ne remplace pas la revue des manifestes et des bindings effectifs. Les droits `get`, `list` et `watch` sur les `secrets`, ainsi que `create`, `update`, `patch` et `delete` pour les charges de travail, demandent une attention particulière. L'accès aux ressources RBAC, `bind`, `escalate` et `impersonate` peut permettre d'accorder ou d'utiliser des droits supplémentaires. `cluster-admin`, `verbs: ["*"]` et `resources: ["*"]` ne constituent pas un choix de départ sûr.

Ces authorization checks spéciaux répondent à des objectifs différents :

- `bind` concerne la création ou la modification d'un `RoleBinding` / `ClusterRoleBinding`. En général, le caller doit déjà posséder les permissions contenues dans le `Role`/`ClusterRole` lié, sur le scope correspondant. L'autorisation explicite `bind` sur un rôle particulier permet d'effectuer le binding même sans disposer de l'ensemble de ces permissions.

- `escalate` ne concerne pas le binding, mais la création ou la modification d'un `Role` / `ClusterRole`. En général, le caller ne peut pas écrire dans un rôle des permissions qu'il ne possède pas lui-même. L'autorisation explicite `escalate` est une exception à cette protection.

- Le `impersonate` classique autorise l'envoi de requêtes au nom de l'utilisateur, du groupe, du ServiceAccount indiqué ou d'un autre identity attribute pris en charge. C'est une capacité distincte, qui ne doit pas être confondue avec `bind` ou `escalate`.

Dans Kubernetes v1.36, le mécanisme beta `ConstrainedImpersonation`, enabled by default, est aussi disponible. Il ajoute des verbs plus étroits de la famille `impersonate:*` et `impersonate-on:*`, afin de limiter non seulement l'identity, mais aussi les actions effectuées en son nom. Les règles RBAC existantes avec le `impersonate` classique continuent de fonctionner ; l'API Server peut utiliser les checks contraints et, au besoin, revenir au `impersonate` classique.

L'autorisation `create` sur `pods` mérite une attention particulière : la simple possibilité de créer un `Pod` peut devenir une étape vers l'augmentation de l'influence d'un sujet, même si ce sujet n'a pas directement accès aux données visées. Le raisonnement est le suivant : le sujet a le droit de créer un `Pod` → le nouveau `Pod` peut indiquer `serviceAccountName` de n'importe quel `ServiceAccount` disponible dans le namespace, si aucune interdiction explicite n'est configurée séparément → via le `ServiceAccount` choisi ou les `Secret`/`ConfigMap`/volumes montés, ce `Pod` peut accéder à des données ou à des droits d'API dont le sujet initial ne disposait pas directement. L'ampleur finale dépend des `ServiceAccount` et volumes réellement disponibles dans le namespace, ainsi que des controls restrictifs distincts (par exemple, `automountServiceAccountToken: false`, PSA/PSS, bindings RBAC limités pour les `ServiceAccount` existants). Le droit de créer une workload ne doit pas être interprété comme un chemin inconditionnel vers n'importe quel `Secret` ou n'importe quel `ServiceAccount` du cluster : il étend l'influence possible exactement dans la mesure permise par le reste de la configuration du namespace.

## 10.5 Application pratique

L'équipe plateforme sépare les identités humaines et les identités machines. Les employés se connectent par OIDC d'entreprise, l'automatisation reçoit des identifiants distincts et chaque composant dans un `Namespace` utilise un `ServiceAccount` séparé.

Pour un service HTTP applicatif qui n'appelle pas l'API Kubernetes, on définit `automountServiceAccountToken: false`. À un contrôleur qui a besoin de l'API, on attribue un `ServiceAccount` distinct et un `Role` avec des ressources et des verb précis. Avant de publier une modification, on vérifie `kubectl auth can-i`, puis on effectue une revue du `RoleBinding` et du `ClusterRoleBinding`.

On recherche régulièrement les bindings vers `default` et les `ClusterRoleBinding` étendus. Lors du départ d'un employé, de la fuite d'un token ou de la perte d'une clé de certificat, les identifiants sont révoqués ou remplacés, et les droits associés sont revus. Ainsi, la fuite d'un token ne devient pas un accès permanent à tout le cluster.

## 10.6 Exam vocabulary / Mini-glossaire

| Terme | Signification |
|---|---|
| authentication | Établissement de l'identité de l'émetteur d'une requête vers l'API. |
| authorization | Décision de savoir si cette identité est autorisée à réaliser une action précise. |
| `ServiceAccount` | Identité Kubernetes pour les processus, généralement exécutés dans un `Pod`. |
| bearer token | Token dont le détenteur obtient les privilèges qui lui sont associés. |
| OIDC | Protocole de connexion de Kubernetes à un fournisseur d'identité externe. |
| RBAC | Gestion des accès via des rôles et des bindings de rôles. |
| `Role` / `ClusterRole` | Ensemble de règles dans un namespace / à l'échelle du cluster. |
| `RoleBinding` / `ClusterRoleBinding` | Binding d'un rôle à un utilisateur, un groupe ou un `ServiceAccount`. |
| `bind` | Autorisation RBAC spéciale pour lier un Role/ClusterRole sans devoir posséder soi-même toutes les permissions du rôle lié. |
| `escalate` | Autorisation RBAC spéciale pour créer/modifier un Role/ClusterRole avec des permissions au-delà des propres permissions du caller. |
| `impersonate` | Permission Kubernetes classique permettant l'impersonation d'une autre identity ; dans v1.36, il existe aussi le beta ConstrainedImpersonation avec des verbs plus étroits. |

## 10.7 Exam Essentials / Points essentiels du chapitre

- Les utilisateurs ordinaires s'authentifient par des mécanismes externes, tandis qu'un `ServiceAccount` est un objet Kubernetes destiné aux processus dans un `Pod`.
- Les certificats clients, bearer tokens, tokens `ServiceAccount` et OIDC établissent l'identité, mais n'accordent aucun droit sans autorisation.
- `default` ne dispose pas automatiquement de droits étendus, mais un binding vers lui fait de tous les pods qui l'utilisent implicitement des porteurs potentiels de ces droits.
- Un token `ServiceAccount` dont l'application n'a pas besoin n'est pas monté grâce à `automountServiceAccountToken: false`.
- RBAC est l'authorizer principal ; `Role` et `RoleBinding` réduisent généralement la portée de l'accès par rapport à leurs variantes de cluster.
- Les autorisations s'additionnent, c'est pourquoi les verb dangereux et les règles wildcard étendues augmentent les conséquences d'une compromission.

## 10.8 À ne pas confondre et comment cela apparaît à l'examen

Dans les MCQ (multiple choice question, question à choix multiple), il faut généralement distinguer authentication et authorization et choisir l'accès sûr le plus étroit. Pièges fréquents :

- croire qu'un `ServiceAccount` ou un token accorde des droits par lui-même ; les droits sont déterminés par les bindings RBAC ;
- confondre `RoleBinding` et `ClusterRoleBinding` : le premier est limité à son namespace ;
- considérer `default` comme intrinsèquement dangereux : le risque dépend des privilèges qui lui sont accordés et du montage du token ;
- prendre OIDC pour une méthode d'autorisation : OIDC confirme l'identité externe, tandis que la décision d'accès revient à l'authorizer ;
- choisir `cluster-admin` ou un wildcard au lieu d'un rôle distinct avec un ensemble précis de ressources et de verb.

Déterminez d'abord l'objet de la question : qui fait la requête, par quel moyen l'identité est établie ou quelle action est autorisée. Vérifiez ensuite la portée : un namespace ou tout le cluster.

## 10.9 Questions d'auto-évaluation

### 1. Quelle affirmation sur un `ServiceAccount` est vraie ?

   - a. Il reçoit automatiquement `cluster-admin` dans son namespace.

   - b. C'est une identité Kubernetes pour les processus dans un `Pod` ; ses droits sont définis par les bindings RBAC.

   - c. Il remplace une `NetworkPolicy` pour l'accès réseau.

   - d. C'est un utilisateur externe qui s'authentifie toujours via OIDC.

<details>
<summary>Réponse et explication</summary>

**Bonne réponse : b.** Un `ServiceAccount` est généralement utilisé par des processus dans des pods, et ses capacités sont définies par les rôles et les bindings. OIDC, `cluster-admin` et les règles réseau ne découlent pas de la seule création d'un `ServiceAccount`.

</details>

### 2. Qu'est-ce qui réduit le risque pour un `Pod` qui n'a pas besoin de l'API Kubernetes ?

   - a. Activer l'authentification anonyme de l'API Server.

   - b. Ajouter `verbs: ["*"]` à un `ClusterRole`.

   - c. Attribuer `default` `ServiceAccount` avec `cluster-admin`.

   - d. Définir `automountServiceAccountToken: false`.

<details>
<summary>Réponse et explication</summary>

**Bonne réponse : d.** Kubernetes ne monte ainsi pas le token `ServiceAccount` dans le pod. Les autres options étendent l'accès ou créent une surface d'attaque inutile.

</details>

### 3. Quel objet définit des autorisations limitées à un seul `Namespace` ?

   - a. `Role`

   - b. `ClusterRoleBinding`

   - c. `NetworkPolicy`

   - d. `ServiceAccount`

<details>
<summary>Réponse et explication</summary>

**Bonne réponse : a.** Un `Role` définit des règles limitées au namespace (quels verb sont autorisés pour quelles ressources), mais n'accorde pas lui-même ces droits à un sujet : pour l'attribution effective, un `RoleBinding` dans le même namespace relie le `Role` aux subjects concernés.

</details>

### 4. Quel mécanisme Kubernetes constitue le choix principal pour gérer les autorisations des utilisateurs et des `ServiceAccount` ?

   - a. Node authorizer

   - b. ABAC

   - c. RBAC

   - d. OIDC

<details>
<summary>Réponse et explication</summary>

**Bonne réponse : c.** RBAC définit des règles d'accès vérifiables au moyen de rôles et de bindings. OIDC concerne l'authentification, le Node authorizer sert les identités de nœud et ABAC repose sur des politiques statiques.

</details>

### 5. Pourquoi l'autorisation `get` sur `secrets` demande-t-elle une attention particulière ?

   - a. Elle peut révéler des credentials, clés et tokens qui donnent ensuite accès à Kubernetes ou à des systèmes externes.
   - b. Elle ne renvoie que les metadata du Secret et ne permet jamais à un client API d'obtenir la valeur stockée.
   - c. Elle donne automatiquement au sujet le droit de créer un `Pod`, même si RBAC ne contient pas l'autorisation correspondante.
   - d. Elle oblige l'API Server à rechiffrer le Secret à chaque lecture et augmente donc les droits du client.

<details>
<summary>Réponse et explication</summary>

**Bonne réponse : a.** Un `Secret` contient souvent des données qui ouvrent l'accès à d'autres ressources. Par conséquent, `get`, et surtout les droits plus étendus `list/watch`, doivent être accordés selon le least privilege. Lire un Secret ne crée pas automatiquement d'autres autorisations RBAC.

</details>

> **Où aller ensuite.** Approfondissez vos compétences pratiques dans le chapitre 10 CKS : RBAC et minimisation de l'accès, le chapitre 11 CKS : ServiceAccounts et tokens, et le chapitre 12 CKS : restriction de l'accès à l'API Kubernetes. La syntaxe de base des rôles est aussi présentée dans le chapitre 38 CKA : RBAC, et la chaîne `ServiceAccount` et admission dans le chapitre 21 CKA. Dans KCSA, poursuivez avec le [chapitre 11](../11/fr.md) sur les Pod Security Standards et Pod Security Admission.

[Table des matières](../README_FR.md) · [Chapitre 09](../09/fr.md) · [Chapitre 11](../11/fr.md)