[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 108 - Admission policies avec Kyverno

## Objectif

Dans ce lab CKS, vous allez installer Kyverno et protéger le namespace `policy-108` par des règles
de policy-as-code. La pratique couvre le validating admission : interdiction du tag `latest`, `runAsNonRoot`
obligatoire, allowlist de registry ; à l'étape optionnelle, la mutation d'un Pod lors de
l'admission. La tâche 6 compare cette approche à un autre mécanisme - l'`ImagePolicyWebhook` intégré,
où la décision sur l'image est prise par un backend HTTP(S) externe via l'API
`ImageReview`, et non par une expression CEL à l'intérieur du cluster. La tâche finale 7 est un troisième admission
engine, distinct : **Gatekeeper (OPA/Rego)**, où vous réparez une policy déjà déployée mais incomplète,
et n'écrivez pas de CEL à l'intérieur de Kyverno. Travaillez uniquement avec les objets et noms indiqués
dans les tâches.

## Vérifiez-vous avant de commencer

<details>
<summary>1. Pourquoi interdire uniquement le tag explicite `:latest` ne couvre-t-il pas tout le risque du mutable-tag ?</summary>

Si l'image est indiquée sans aucun tag (par exemple, `nginx`), Docker/OCI la résout par défaut en `nginx:latest` - implicit latest. Une policy qui ne vérifie que la correspondance littérale de la chaîne `:latest` laissera passer cette image, bien que sémantiquement ce soit la même chose qu'un `:latest` explicite. Une policy correcte doit rejeter à la fois le latest explicite et implicite - ou bien exiger un versioned tag/digest explicite.
</details>

<details>
<summary>2. Pourquoi une validating policy doit-elle vérifier `ephemeralContainers` séparément de `containers`/`initContainers` ?</summary>

`kubectl debug` ajoute un ephemeral container à un Pod DÉJÀ existant via un subresource d'API distinct (`pods/ephemeralcontainers`), et non via un CREATE/UPDATE ordinaire du Pod. Si la policy ne correspond qu'à la ressource `pods` sans inclure explicitement ce subresource, une tentative d'ajouter un ephemeral container non vérifié/untrusted peut passer à côté de toutes les validating policies écrites pour les conteneurs ordinaires.
</details>

<details>
<summary>3. Quelle est la différence essentielle entre `ValidatingPolicy` et `MutatingPolicy` dans Kyverno ?</summary>

`ValidatingPolicy` ne fait que vérifier la requête et l'autorise ou la rejette (Allow/Deny) - l'objet n'est pas modifié. `MutatingPolicy` MODIFIE l'objet avant l'enregistrement (ajoute/change des champs, par exemple un label) - la requête passe quand même, mais avec un contenu modifié. La tâche 5 utilise la mutation précisément parce que le but est d'ajouter un label automatiquement, et non de rejeter le Pod.
</details>

## Infrastructure

L'environnement est déployé par Terragrunt dans AWS `eu-central-1` :

| Composant | Rôle |
|---|---|
| `vpc` | VPC `10.10.0.0/16` avec des sous-réseaux publics |
| `ssh-keys` | clés d'accès aux nœuds |
| `k8s-1` | cluster kubeadm mono-nœud avec Kubernetes `1.36.0`, containerd et **Calico** |
| `worker` | machine de travail avec `kubectl`, Helm et `/usr/local/bin/install-kyverno` |

Le control-plane autorise les Pods ordinaires, aucun worker Kubernetes distinct n'est donc créé.
Kyverno n'est volontairement **pas installé** dans l'état initial : cela fait partie de la tâche 1. Sur la
machine de travail, un installer figé est préparé, qui n'oblige pas à chercher le chart à la main.
Le lab fige Kyverno `1.19` (Helm chart `3.9.0`) et utilise les API stables basées sur CEL
`policies.kyverno.io/v1`. Les `Policy`/`ClusterPolicy` legacy de `kyverno.io/v1` sont, depuis cette version,
deprecated et ne sont considérés que comme migration material.

Contrairement à Kyverno, **Gatekeeper (OPA) pour la tâche 7 est déjà installé** par le bootstrap
du cluster, avec un `ConstraintTemplate` et un `Constraint` de départ (volontairement incomplets).
C'est fait exprès : la tâche 7 vérifie la capacité à trouver et compléter du Rego dans un
`ConstraintTemplate` déjà existant, et non à installer un admission engine à partir de zéro - cette partie
est déjà exercée par la tâche 1 pour Kyverno. La tâche 7 fonctionne dans un namespace distinct
`gatekeeper-108`, isolé des tâches 1-5 de Kyverno (`policy-108`), afin qu'un Pod ne puisse pas
être rejeté simultanément par deux admission engines différents.

## Déploiement

```bash
TASK=108 make run_cks_task
```

Connectez-vous en SSH à la machine de travail. Le contexte `cluster1-admin@cluster1` est déjà configuré.

```bash
time_left
check_result
```

## Tâches

---
| **1** | **Installer Kyverno** |
| :---: | :--- |
| Ce qu'on fait | • Installez Kyverno dans le namespace `kyverno`.<br/>• Utilisez la commande préparée sur le worker `/usr/local/bin/install-kyverno` ; elle applique le Helm chart figé.<br/>• Attendez que l'admission controller soit disponible. |
| Critères d'acceptation | • Dans le cluster, il y a le CRD `validatingpolicies.policies.kyverno.io`<br/>• La version de Kyverno est `1.19.x`<br/>• Au moins un Deployment du namespace `kyverno` a une réplique disponible |

<details>
<summary>💡 Indice pour la tâche 1</summary>

`/usr/local/bin/install-kyverno` est déjà configuré sur la version figée - n'essayez pas d'installer Kyverno via `helm install` à la main avec un autre chart, cela peut conduire à une version incompatible des CRD. Après l'installation, patientez : le Pod de l'admission controller doit passer à `Available`, ce qui n'est pas instantané.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

La première commande doit renvoyer le CRD lui-même (et non l'erreur `NotFound`) ; la version de l'image doit
contenir `v1.19.` ; au moins un Deployment doit avoir `AVAILABLE` supérieur à `0`.
</details>

---
| **2** | **Interdire les images avec le tag `latest`** |
| :---: | :--- |
| Ce qu'on fait | • Créez une `ValidatingPolicy` basée sur CEL `deny-latest-tag` (`policies.kyverno.io/v1`) avec `validationActions: [Deny]`.<br/>• Elle doit s'appliquer aux Pods et au subresource `pods/ephemeralcontainers` du namespace `policy-108`.<br/>• Elle doit rejeter toute image dans `containers`, `initContainers` ou `ephemeralContainers` qui est un `:latest` explicite OU un latest implicite (une image sans tag et sans digest du tout). |
| Critères d'acceptation | • La policy existe et fonctionne en mode Deny<br/>• L'admission rejette à la fois le `:latest` explicite et le latest implicite (untagged) dans chacune des trois listes de conteneurs, y compris une image avec un port de registry sans tag (`registry.example:5000/app`), et accepte les versioned trusted images et les images épinglées par digest dans chaque liste<br/>• Lors d'un UPDATE d'un Pod existant, le changement de `spec.containers[*].image` ou `spec.initContainers[*].image` vers `:latest` est aussi rejeté par cette policy (les champs image ordinaires d'un Pod admettent l'UPDATE in-place) |

<details>
<summary>💡 Indice pour la tâche 2</summary>

`matchConstraints.resourceRules` doit couvrir à la fois `pods` et le subresource
`pods/ephemeralcontainers` séparément - sinon `kubectl debug` passera à côté de la policy. Pour
la logique CEL elle-même : décomposez la chaîne de l'image en `registry/path` et `tag` par le dernier `:`
APRÈS le dernier `/` (la présence de `:` avant le dernier `/` peut faire partie du port du registry, et
non du tag) ; si après la décomposition il n'y a pas de tag du tout - c'est un latest implicite ; s'il y a un tag, mais qu'il
est égal à `latest` - c'est aussi un cas interdit ; le digest (`@sha256:...`) est un cas à part, toujours
autorisé, qui ne relève pas du tout du tag.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

Avant d'appliquer la policy, assurez-vous que le Pod fautif passe l'admission en général
(baseline) - sinon on ne sait pas si le denial est causé par votre policy ou par autre chose :

```bash
# baseline : avant d'appliquer la policy - doit passer (exit 0)
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "baseline exit: $?"
```

Appliquez la policy, puis répétez LE MÊME manifest - il doit maintenant se terminer par une erreur
d'admission (exit non 0), et le message doit faire référence à votre policy :

```bash
kubectl apply -f deny-latest-tag.yaml   # votre fichier de policy
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-latest
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:latest
EOF
echo "after-policy exit: $?"
```

Répétez le même cycle baseline→apply→probe→compare pour : une image sans tag du tout
(`registry.k8s.io/pause`), `registry.example:5000/app` (les deux-points avant le dernier `/` sont le port du registry, et non le tag), `:latest` dans `initContainers`, et `:latest`/untagged via
`kubectl debug --image=...` sur un Pod autorisé déjà en cours d'exécution (subresource `pods/ephemeralcontainers`).
Enfin, vérifiez le positive control : un versioned tag doit passer aussi
après l'application de la policy, et pas seulement avant.
</details>

---
| **3** | **Exiger une exécution sans root** |
| :---: | :--- |
| Ce qu'on fait | • Créez une `ValidatingPolicy` basée sur CEL `require-run-as-non-root` en mode Deny.<br/>• Pour chaque Pod dans `policy-108`, le champ `spec.securityContext.runAsNonRoot` doit être explicitement égal à `true`.<br/>• Au niveau du Pod et de tous les conteneurs sont interdits `runAsUser: 0` et `runAsNonRoot: false` au niveau du conteneur : les réglages du conteneur peuvent redéfinir le securityContext au niveau du Pod. |
| Critères d'acceptation | • La policy existe et est Deny<br/>• Un Pod avec `runAsNonRoot: false` ou sans ce champ, `runAsUser: 0` au niveau du Pod, ainsi qu'un conteneur avec `runAsNonRoot: false` / `runAsUser: 0` dans `containers`, `initContainers`, `ephemeralContainers` sont rejetés précisément par cette policy<br/>• Un `runAsNonRoot: true`, `runAsUser: 1000` explicite et sûr au niveau du conteneur est accepté |

<details>
<summary>💡 Indice pour la tâche 3</summary>

Vérifiez précisément la valeur EXPLICITE `true`, et non « l'absence de `false` » - une expression CEL de la forme `object.spec.securityContext.runAsNonRoot == true` ne passera pas si le champ n'est pas défini du tout (`null != true`), et c'est ici CE QUI EST EXIGÉ : la tâche rejette à la fois un `false` explicite et un champ absent - les deux cas doivent être denied, et pas seulement le `false` explicite.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

```bash
# baseline : avant d'appliquer la policy, les deux variantes doivent passer
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-false
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: false
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-root-unset
  namespace: policy-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

Appliquez la policy et répétez les deux manifests - LES DEUX doivent maintenant se terminer par une erreur
d'admission. Vérifiez ensuite le positive control : le même Pod, mais avec
`runAsNonRoot: true` explicite, doit passer aussi après l'application de la policy.
</details>

---
| **4** | **Allowlist de container registry** |
| :---: | :--- |
| Ce qu'on fait | • Créez une `ValidatingPolicy` basée sur CEL `allow-approved-registries` en mode Deny.<br/>• Pour chaque conteneur (`containers`, `initContainers`, `ephemeralContainers`), n'autorisez que `registry.k8s.io/*` ou `ghcr.io/cks-lab/*`.<br/>• Interdisez les autres image registry. |
| Critères d'acceptation | • La policy existe et est Deny<br/>• Une untrusted image est rejetée dans les trois listes<br/>• Les deux approved prefixes (`registry.k8s.io/` et `ghcr.io/cks-lab/`) sont admis dans chacune des trois listes<br/>• Un UPDATE ordinaire d'un Pod qui change l'image vers un unapproved registry est rejeté par la policy elle-même<br/>• On vérifie aussi d'autres unapproved registry et des host/path-lookalikes dans les listes init/ephemeral |

<details>
<summary>💡 Indice pour la tâche 4</summary>

`startsWith('registry.k8s.io/')` est la vérification de préfixe la plus fiable, mais assurez-vous que les deux registry autorisés sont vérifiés via OR (l'un ou l'autre convient), et non AND (les deux à la fois, ce qui est impossible pour une seule image). Vérifiez précisément une ALLOWLIST (l'image n'est admise QUE si elle correspond à l'un des deux préfixes), et non une denylist visant uniquement `docker.io` - une policy écrite comme « si c'est `docker.io` - deny, sinon allow » laissera passer `quay.io`, les images unqualified et tout autre registry tiers. Assurez-vous aussi que le préfixe est comparé avec la `/` FINALE (`registry.k8s.io/`, et pas simplement `registry.k8s.io`), sinon un host d'orthographe proche (`registry.k8s.io.evil.example`) peut passer par une correspondance case-insensitive ou incomplète. Comme dans la tâche 2, n'oubliez pas `ephemeralContainers` - c'est le même schéma de vérification des trois listes de conteneurs.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

```bash
# baseline : avant d'appliquer la policy - un untrusted registry doit passer
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF
```

Appliquez la policy, répétez le même manifest - il doit maintenant être denied. C'est UNE seule
valeur untrusted concrète (`docker.io`), et non la preuve d'une allowlist complète -
une policy qui interdit simplement littéralement `docker.io`, mais laisse passer,
par exemple, une image unqualified (implicit Docker Hub sans host explicite), `quay.io` ou
un host d'orthographe proche (`registry.k8s.io.evil.example`), passera aussi cette SEULE
vérification. Répétez le même baseline→apply→probe→compare au minimum pour : une image
unqualified (`busybox:1.36` sans host du tout), un autre registry externe explicite
(`quay.io/...`), un host/path d'orthographe proche (`registry.k8s.io.evil.example/...`,
`ghcr.io/cks-lab.evil/...`), une untrusted image dans `initContainers`, et une image untrusted/trusted
via `kubectl debug` sur un Pod autorisé déjà en cours d'exécution. Enfin, positive control : un Pod avec LES DEUX conteneurs (main + init) de
`registry.k8s.io`/`ghcr.io/cks-lab` doit passer ; vérifiez aussi `ghcr.io/cks-lab/*`
dans les conteneurs init et ephemeral, et pas seulement dans `containers`.
</details>

---
| **5** | **Optionnel : mutation d'un label via Kyverno** |
| :---: | :--- |
| Ce qu'on fait | • Créez une `MutatingPolicy` basée sur CEL `add-kyverno-managed-label` (`policies.kyverno.io/v1`), qui ajoute aux Pods du namespace `policy-108` le label `security.cks.io/managed-by: kyverno`, s'il est absent.<br/>• Utilisez la mutation, et non la validation.<br/>• Ne mutez pas les Pods d'autres namespaces. |
| Critères d'acceptation | • Un server-side dry-run d'un Pod avec un registry autorisé et `runAsNonRoot: true`, qui n'a pas encore ce label, le reçoit après la mutation avec la valeur `kyverno`<br/>• Un Pod qui a DÉJÀ le label avec une autre valeur conserve la valeur d'origine<br/>• Un Pod dans `default` reste sans ce label<br/>• Cette étape est affichée dans `check_result`, mais il est admis de l'omettre |

<details>
<summary>💡 Indice pour la tâche 5</summary>

Cette étape est optionnelle - si vous n'avez plus de temps, vous pouvez l'omettre sans risque pour le reste du lab. Le Pod de test pour vérifier la mutation doit déjà passer les policies des tâches 2-4 (trusted registry, non-root) - s'il est lui-même rejeté par l'une des policies précédentes, vous ne verrez pas du tout le résultat de la mutation. « S'il est absent » dans la tâche n'est pas seulement un souhait : la mutation doit vérifier explicitement la présence du label et ne pas toucher à l'objet s'il est déjà là, sinon la tâche n'est pas accomplie, même si un Pod sans label reçoit la bonne valeur.
</details>

---
| **6** | **ImagePolicyWebhook : backend externe au lieu d'une CEL policy** |
| :---: | :--- |
| Ce qu'on fait | • Sur la machine de travail est déjà préparé `/opt/image-policy-backend/server.py` - un serveur HTTPS minimal qui implémente l'API `ImageReview` (rejette les images avec le tag `:latest` ou sans tag du tout).<br/>• Déployez-le comme Deployment dans le namespace `image-policy`, derrière un Service `image-policy-backend` sur le port `8443`. Le backend doit accepter les connexions en TLS (le contrat upstream de `ImagePolicyWebhook` exige HTTPS, le HTTP simple n'est pas pris en charge).<br/>• Sur `control-plane` (`ssh`, puis `sudo -i`), configurez un `AdmissionConfiguration` pour le plugin `ImagePolicyWebhook` (`defaultAllow: false`) et un kubeconfig pointant vers votre backend.<br/>• Dans le static manifest `kube-apiserver.yaml`, **ajoutez** `ImagePolicyWebhook` à la liste déjà existante de `--enable-admission-plugins` (ne remplacez pas toute la liste - sinon vous risquez de désactiver des plugins déjà activés) et activez `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`.<br/>• Après le rétablissement de l'API, créez un Pod avec `:latest` - il doit être rejeté ; puis un Pod avec un tag figé - il doit être créé. |
| Critères d'acceptation | • `image-policy-backend` Available<br/>• Kube-apiserver healthy avec le plugin ajouté (et non remplacé) et `--runtime-config`<br/>• Le kubeconfig du backend utilise HTTPS `https://<ClusterIP Service image-policy-backend>:8443/imagepolicy`<br/>• Un Pod avec `:latest` et latest implicite (y compris un registry-port sans tag) est rejeté précisément par ImagePolicyWebhook dans le namespace `default` - aussi bien dans un Pod ordinaire que dans un init/ephemeral container<br/>• L'annotation utilisateur `alpha.image-policy.k8s.io/break-glass: "true"` ne donne aucune exception<br/>• Le namespace `policy-108` est réservé à Kyverno des tâches 2–4, afin que deux mécanismes d'admission indépendants ne masquent pas le refus l'un de l'autre<br/>• Pour cela, lorsque `ImageReview.spec.namespace == policy-108`, le backend délègue la décision à Kyverno, et dans tous les autres namespaces ImagePolicyWebhook continue de fonctionner<br/>• Le Pod avec un tag figé est créé et Running<br/>• Le Service perd réellement ses Endpoints pendant le backend outage, l'API refuse à cause de l'indisponibilité de cet endpoint (`defaultAllow: false`), puis le Service selector et l'admission se rétablissent exactement à l'état d'origine |

<details>
<summary>💡 Indice pour la tâche 6</summary>

`ImagePolicyWebhook` est un mécanisme fondamentalement différent de Kyverno des tâches 1-5 : la décision est prise par un backend HTTPS externe via l'API `ImageReview`, et non par une expression CEL à l'intérieur du cluster. Utilisez le `/opt/image-policy-backend/server.py` prêt à l'emploi, qui se trouve sur la machine de travail (par exemple, empaquetez-le dans un ConfigMap pour le Deployment du backend ; sur le `control-plane`, il faut copier uniquement le certificat CA pour le kubeconfig du webhook) - la tâche vérifie la compréhension du wiring de l'admission plugin, du contrat TLS et de l'API ImageReview, et non la capacité à écrire un serveur HTTP à partir de zéro. Pour TLS : créez d'abord le Service (pour connaître le `ClusterIP`), puis un certificat auto-signé avec cette IP dans le SAN (`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`), puis le Deployment, qui monte à la fois le code et le certificat. Ne remplacez pas entièrement la valeur existante de `--enable-admission-plugins` par une nouvelle - ajoutez `ImagePolicyWebhook`, séparé par une virgule, aux plugins déjà activés (en général, `NodeRestriction` y est déjà). N'oubliez pas non plus `--runtime-config=imagepolicy.k8s.io/v1alpha1=true` - sans l'activation explicite de cette API, le backend ne sera pas du tout appelé. Le namespace `image-policy` n'est pas créé à l'avance - créez-le vous-même avant le Deployment/Service. Si vous êtes bloqué sur la séquence détaillée de ressources/chemins/flags, l'ordre d'actions de référence est donné dans la solution.
</details>

---
| **7** | **Gatekeeper ConstraintTemplate : compléter la blocklist Rego** |
| :---: | :--- |
| Ce qu'on fait | • Dans le cluster est déjà installé **Gatekeeper** (OPA), ainsi que le `ConstraintTemplate` `k8sblockedregistries` et le `Constraint` `K8sBlockedRegistries/deny-bad-registries`, limité à un namespace distinct `gatekeeper-108` (et non `policy-108` - c'est un terrain d'essai séparé des tâches 1-5 de Kyverno, afin que Kyverno et Gatekeeper ne rejettent pas le même Pod simultanément).<br/>• Le Rego à l'intérieur du `ConstraintTemplate` contient déjà plusieurs registry bloqués (`untrusted-registry.example`, `docker-fake.test`), mais **ne contient volontairement pas** `very-bad-registry.test`.<br/>• Trouvez `ConstraintTemplate.spec.targets[].rego` et ajoutez-y une règle pour `very-bad-registry.test` - précisément dans le Rego, et non dans les paramètres du `Constraint`.<br/>• `deny-bad-registries` est déjà tout à fait correct et n'utilise pas du tout `spec.parameters` - il n'est pas nécessaire d'y toucher. |
| Critères d'acceptation | • Le `ConstraintTemplate k8sblockedregistries` et le Constraint d'origine `K8sBlockedRegistries/deny-bad-registries` existent<br/>• Le Rego conserve les deux règles actives d'origine (`untrusted-registry.example`, `docker-fake.test`) et contient la nouvelle règle active pour `very-bad-registry.test`<br/>• Un Pod avec chacun de ces trois registry dans `gatekeeper-108` est rejeté précisément par le Constraint `deny-bad-registries`<br/>• Un Pod avec une image du `registry.k8s.io` de confiance passe<br/>• Le Constraint reste Pod-only, limité à `gatekeeper-108`, sans parameters/selectors/exclusions<br/>• Aucun Constraint supplémentaire de ce type n'est créé |

<details>
<summary>💡 Indice pour la tâche 7</summary>

Trouvez le ConstraintTemplate via `kubectl get constrainttemplate k8sblockedregistries -o yaml`. Le Rego se trouve dans `spec.targets[].rego` comme chaîne multiligne - c'est elle qu'il faut modifier (`kubectl edit constrainttemplate k8sblockedregistries`, ou `get -o yaml` → modification → `apply`). Le Rego existant déclare les registry bloqués par des faits distincts de la forme `blocked_registry("untrusted-registry.example")` - ajoutez une ligne de plus de ce type pour `very-bad-registry.test`, sans supprimer ni remplacer celles qui existent déjà. Ne le confondez pas avec `Constraint.spec.parameters` - dans cette version de la policy, le Constraint n'utilise pas du tout de parameters, il n'y a rien à modifier là-bas.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

Baseline - AVANT la correction : un Pod de `very-bad-registry.test` doit passer (le Rego ne
le couvre pas encore), et celui de `untrusted-registry.example`, déjà bloqué, doit être rejeté :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad baseline exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad baseline exit: $?"
```

Complétez le Rego, répétez LE MÊME manifest (sous un nouveau nom, l'ancien Pod est déjà
« créé » via dry-run et n'est pas enregistré) - on attend maintenant une erreur d'admission de
Gatekeeper, se référant précisément à `k8sblockedregistries`, pour LES DEUX registry :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-new-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
echo "new-bad after-fix exit: $?"

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-old-bad-2
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
echo "old-bad after-fix exit: $?"
```

Vérifiez le positive control - le registry de confiance doit passer aussi après la correction :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-trusted-registry
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
echo "trusted exit: $?"
```
</details>

## Vérification

Sur la machine de travail, exécutez :

```bash
check_result
```

La vérification contient Init et sept tests. Les quatre premiers, le sixième et le septième sont obligatoires. Le cinquième
test exécute la vérification de la mutation, mais ne fait pas échouer le lab si la policy
optionnelle n'est pas créée. Les tâches 2-4 et 7 utilisent `--dry-run=server`, de sorte que les images ne sont pas
téléchargées et que les Pods ne restent pas dans le namespace ; la tâche 6 vérifie l'admission réelle (non dry-run)
via ImagePolicyWebhook, c'est pourquoi le Pod `webhook-pinned-ok` est réellement
créé.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD)

## Suppression

```bash
TASK=108 make delete_cks_task
```

## Compatibilité et sémantique exacte de l'interdiction des images

Le lab fige Kubernetes 1.36.0 et Kyverno 1.19 pour faire connaissance avec les nouvelles
API `policies.kyverno.io/v1`. C'est une **forward-looking / unsupported combination** : Kyverno
1.19 est officiellement testé avec Kubernetes 1.33–1.35, et non 1.36. Avant toute application hors du
lab, choisissez une matrice de versions prise en charge et comparez les release notes.

Dans la tâche 2, par « interdiction de `latest` » on entend aussi l'interdiction du `latest` implicite : `nginx`
sans tag ni digest est aussi inadmissible que `nginx:latest`. Seules sont autorisées les images avec un
tag explicite différent de `latest`, ou avec un digest (`@sha256:...`). La tâche ne donne pas la logique CEL exacte toute prête
pour ce critère - voir l'indice de la tâche 2, si vous avez besoin d'un appui supplémentaire.
