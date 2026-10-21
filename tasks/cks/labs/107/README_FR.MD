[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 107 - Pod Security Admission : restricted, audit/warn et read-only root filesystem

## Objectif

Dans ce lab CKS, vous allez configurer le **Pod Security Admission (PSA)** intégré via
les labels du namespace. Pour le namespace de production, `restricted` sera activé en mode
`enforce`, le refus d'un Pod non sûr sera vérifié et un Pod hardened qui passe sera déployé.
Pour un namespace distinct, vous activerez les modes d'observation `audit` et `warn` du niveau
`baseline`. Pour finir, le root filesystem du conteneur deviendra read-only, et la seule
écriture nécessaire sera autorisée dans un `emptyDir`.

Travaillez uniquement avec les objets des tâches. Dans le cluster, les namespaces vides
`psa-restricted-107`, `psa-observe-107` et `psa-controller-107` ont été créés à l'avance ; il n'y a ni PSA-labels ni workload dedans.

## Vérifiez-vous avant de commencer

<details>
<summary>1. En quoi `enforce` diffère-t-il de `audit`/`warn` dans Pod Security Admission ?</summary>

`enforce` bloque réellement la création d'un Pod qui enfreint le niveau PSS choisi - l'admission request se termine par une erreur. `audit`/`warn` NE bloquent PAS la requête : le Pod est tout de même créé, mais `audit` ajoute une annotation à l'audit log de kube-apiserver, et `warn` affiche à l'utilisateur un avertissement textuel lors de `kubectl apply`. Ce sont des niveaux de responsabilité différents : `audit`/`warn` servent à observer avant d'activer le vrai blocage, `enforce` est la protection proprement dite.
</details>

<details>
<summary>2. Pourquoi faut-il figer le label `*-version` avec le niveau PSS pour le namespace ?</summary>

Sans version figée (`enforce-version`), PSA utilisera la version actuelle de Kubernetes à chaque vérification - si le cluster est mis à jour, l'ensemble de règles de `restricted`/`baseline` peut changer à votre insu, et un Pod qui passait hier peut commencer à être rejeté aujourd'hui sans que vous ayez rien fait. Figer la version rend le comportement prévisible et reproductible indépendamment des futures mises à jour du cluster.
</details>

<details>
<summary>3. Pourquoi la `ValidatingAdmissionPolicy` de la tâche 6 ne duplique-t-elle pas PSA, mais le complète-t-elle ?</summary>

PSS `restricted` définit un ensemble fixe et standardisé de champs de sécurité (non-root, capabilities, seccomp, escalation). `automountServiceAccountToken` NE fait PAS partie de cet ensemble - PSA ne le vérifie pas du tout. Donc un Pod peut être entièrement compatible avec `restricted` et recevoir tout de même discrètement un API-token monté dont il n'a pas besoin. Une `ValidatingAdmissionPolicy` custom comble précisément cette lacune, sans chercher à remplacer ni dupliquer ce que PSA fait déjà.
</details>

## Infrastructure

L'environnement est déployé via Terragrunt dans AWS `eu-central-1` :

| Composant | Rôle |
|---|---|
| `vpc` | VPC `10.10.0.0/16` avec des sous-réseaux publics |
| `ssh-keys` | clés SSH pour accéder aux machines |
| `k8s-1` | cluster kubeadm mono-nœud avec Kubernetes `1.36.0`, containerd et **Calico** |
| `worker` | machine de travail avec `kubectl`, le contexte `cluster1-admin@cluster1` et `check_result` |

Le control-plane accepte les Pods ordinaires, un nœud worker Kubernetes distinct n'est donc pas
nécessaire. Toutes les tâches s'effectuent sur la machine de travail.

## Déploiement

```bash
TASK=107 make run_cks_task
```

Connectez-vous en SSH à la machine de travail et vérifiez l'accès au cluster :

```bash
time_left
kubectl get nodes
check_result
```

## Tâches

---
| **1** | **Enforce restricted avec version figée** |
| :---: | :--- |
| Ce qu'on fait | Sur le namespace `psa-restricted-107`, définissez `pod-security.kubernetes.io/enforce=restricted` et `pod-security.kubernetes.io/enforce-version=v1.36`. Assurez-vous que PSA rejette réellement un Pod non sûr : un server-side dry-run d'un Pod avec `hostNetwork: true` dans ce namespace doit se terminer par une erreur avec `violates PodSecurity`. Ne modifiez pas les labels des namespaces système. |
| Critères d'acceptation | Les deux enforce-labels ont les valeurs exactes ; le Pod non sûr ne passe pas l'admission dans `psa-restricted-107` ; les namespaces système `kube-system`, `kube-public` et `kube-node-lease` ne reçoivent pas de labels `pod-security.kubernetes.io/*` dans le cadre de ce lab. |

<details>
<summary>💡 Indice pour la tâche 1</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - les deux labels s'appliquent instantanément, PSA n'exige aucun redémarrage. Vérifiez-vous via `kubectl apply --dry-run=server` avec `hostNetwork: true` - précisément `--dry-run=server` (et non `client`), car les admission controllers, y compris PSA, ne fonctionnent que côté serveur.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

D'abord le baseline - AVANT de définir les labels, assurez-vous que le même manifest non sûr
passe (sinon on ne sait pas si le denial est causé par votre enforce label ou par autre chose) :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "baseline exit: $?"
```

Définissez les deux labels, puis répétez LE MÊME manifest - il doit maintenant y avoir une erreur
d'admission avec le texte `violates PodSecurity` :

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-hostnetwork
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "after-label exit: $?"
```
</details>

---
| **2** | **Hardened Pod qui passe restricted** |
| :---: | :--- |
| Ce qu'on fait | Créez un Pod `restricted-app` dans `psa-restricted-107` à partir de `busybox:1.36`, qui ne s'exécute pas en root et ne se termine pas immédiatement. Définissez au niveau du Pod `runAsNonRoot: true`, `runAsUser: 1000` et `seccompProfile: RuntimeDefault`. Dans le securityContext du container, interdisez le privilege escalation, retirez la capability `ALL`, laissez explicitement `privileged: false` et définissez `seccompProfile: RuntimeDefault`. |
| Critères d'acceptation | Le Pod est accepté par PSA et est en cours d'exécution ; il fonctionne en UID 1000/non-root, et aucun container/init/ephemeral container ne redéfinit le `runAsUser: 1000` au niveau du Pod ; seccomp - `RuntimeDefault` ; escalation et privileged sont interdits ; les capabilities `ALL` sont retirées. |

<details>
<summary>💡 Indice pour la tâche 2</summary>

Si le Pod reçoit un admission rejection - lisez attentivement le message d'erreur, il nomme généralement le champ manquant EXACT (par exemple, "container has no capabilities.drop"). Un détail important sur la sémantique de PSS `restricted` dans Kubernetes 1.36 : il exige un `seccompProfile` effectif (pas nécessairement dupliqué littéralement) admissible - le profil au niveau du Pod (`spec.securityContext.seccompProfile.type`) peut être hérité par les conteneurs dont le champ propre n'est pas défini, et inversement, le champ au niveau du container suffit s'il est explicitement défini sur TOUS les conteneurs, même sans profil au niveau du Pod. C'est-à-dire que PSS lui-même n'exige pas littéralement LES DEUX niveaux à la fois. **Dans ce lab, nous demandons volontairement d'indiquer `RuntimeDefault` explicitement à la fois sur le Pod et sur le conteneur** - non pas parce que PSS l'exige, mais pour que vous vous exerciez avec les deux niveaux de configuration. De même, `runAsUser: 1000` est une décision d'explicit hardening propre à ce lab : PSS `restricted` interdit l'UID `0`, mais n'exige pas concrètement `1000` (toute valeur non nulle ou l'absence complète du champ est admissible pour PSS lui-même).
</details>

---
| **3** | **Modes d'observation baseline** |
| :---: | :--- |
| Ce qu'on fait | Sur le namespace `psa-observe-107`, activez les deux modes de PSA : `pod-security.kubernetes.io/audit=baseline`, `pod-security.kubernetes.io/audit-version=v1.36`, `pod-security.kubernetes.io/warn=baseline`, `pod-security.kubernetes.io/warn-version=v1.36`. N'ajoutez pas `enforce` : c'est un namespace pour l'observation progressive avant le blocage. |
| Critères d'acceptation | Les quatre labels audit/warn sont présents avec le niveau `baseline` et la version `v1.36` ; l'enforce-label est absent. |

<details>
<summary>💡 Indice pour la tâche 3</summary>

Quatre labels distincts - il est facile d'en oublier un (surtout le `-version` de l'un des modes). Vérifiez les quatre d'un coup : `kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

Baseline - AVANT de définir les labels, le manifest fautif doit passer sans avertissement de PSA
(le namespace n'est pas encore observé) :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
```

Définissez les quatre labels, puis répétez LE MÊME manifest - maintenant `kubectl apply`
doit afficher `Warning: ... would violate PodSecurity "baseline:v1.36"`, et la commande
doit tout de même se terminer avec succès (exit 0), et non par une erreur :

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-baseline-violation
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
EOF
echo "exit code: $?"
```
</details>

---
| **4** | **Warn/audit ne bloquent pas le legacy workload** |
| :---: | :--- |
| Ce qu'on fait | Créez dans `psa-observe-107` un Pod `baseline-audit-sample` à partir de `busybox:1.36`, qui fonctionne avec `hostNetwork: true` et exécute `sleep 3600`. Lors du `kubectl apply`, consignez l'avertissement de PSA sur la violation de baseline : le Pod doit être créé, car `warn` et `audit` n'interdisent pas la requête par eux-mêmes. |
| Critères d'acceptation | `baseline-audit-sample` existe, a `hostNetwork: true` et a été admis par l'API ; dans le namespace, il n'y a toujours pas d'enforce-mode. |

<details>
<summary>💡 Indice pour la tâche 4</summary>

Si le Pod n'a PAS été créé - vérifiez si vous n'avez pas défini par accident le label `enforce` dans la tâche 3 au lieu de seulement `audit`/`warn`. Le Warning de PSA apparaît directement dans la sortie de `kubectl apply` (`Warning: would violate PodSecurity "baseline:v1.36"`), inutile de le chercher dans un log distinct.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

Cette tâche répète en fait le self-check de la tâche 3, mais avec un Pod permanent. Après
la création de `baseline-audit-sample`, assurez-vous qu'il existe réellement et est
`Running`/`Pending` (qu'il n'a pas été rejeté) :

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

Comparez avec le namespace `psa-restricted-107` (tâche 1) : le même manifest nonsafe là-bas
DOIT être rejeté, et ici - accepté. La différence tient précisément au label `enforce`, qui est présent
dans un namespace et absent dans l'autre :

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **Read-only root filesystem avec un emptyDir inscriptible** |
| :---: | :--- |
| Ce qu'on fait | Complétez `restricted-app` : sur le conteneur, activez `readOnlyRootFilesystem: true`. Créez un volume `writable-tmp` de type `emptyDir` (`medium: Memory` recommandé, pour que les fichiers temporaires n'aillent pas sur le disque du nœud) et montez-le dans `/tmp` sans `readOnly: true`. Le conteneur n'est autorisé à écrire que dans ce volume temporaire ; n'utilisez pas `hostPath`. Démontrez les deux issues par un appel en direct dans le Pod : une tentative d'écriture à la racine du conteneur (par exemple, `touch /root-write-test.txt`) doit se terminer par l'erreur `Read-only file system`, et l'écriture dans `/tmp/test.txt` doit réussir. Lors de la modification de champs immuables du Pod, supprimez et recréez `restricted-app` avec le même nom. |
| Critères d'acceptation | Le conteneur a un read-only root filesystem ; l'`emptyDir` nommé `writable-tmp` est monté dans `/tmp` en writable ; pour les regular containers, c'est le seul `volumeMount` déclaratif writable, et tous les `volumeMounts` supplémentaires sont read-only ; les réglages hardened de la tâche 2 sont conservés ; la tentative d'écriture en direct à la racine du conteneur renvoie `Read-only file system`, et l'écriture dans `/tmp/test.txt` se termine avec succès et avec un contenu lisible. |

<details>
<summary>💡 Indice pour la tâche 5</summary>

`readOnlyRootFilesystem` fait partie des champs qui ne peuvent pas être modifiés sur un Pod déjà existant (immutable field) - `kubectl apply` avec un securityContext modifié renverra une erreur. Supprimez le Pod (`kubectl delete pod restricted-app`) et recréez-le avec le même nom, plutôt que d'essayer de mettre à jour l'existant sur place.
</details>

---
| **6** | **Native ValidatingAdmissionPolicy : exiger `automountServiceAccountToken: false`** |
| :---: | :--- |
| Ce qu'on fait | • PSA `restricted` exige déjà `allowPrivilegeEscalation: false`, un `capabilities.drop` contenant `ALL`, non-root et seccomp - la tâche 2 montre précisément cela.<br/>• Mais PSS `restricted` **ne vérifie pas** `automountServiceAccountToken` : un Pod qui n'a pas besoin de la Kubernetes API peut recevoir discrètement un ServiceAccount token monté et passer entièrement PSA. C'est un control distinct, non couvert par PSS, c'est pourquoi une `ValidatingAdmissionPolicy` custom est ici de mise, et non la duplication du PSA intégré.<br/>• Créez une `ValidatingAdmissionPolicy` `require-no-automount-token` avec une expression CEL exigeant `automountServiceAccountToken == false` au niveau du Pod.<br/>• Appliquez un `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding`, limité par `matchResources.namespaceSelector` à `psa-restricted-107`, avec `validationActions: [Deny]`.<br/>• Démontrez les trois états par server-side dry-run : un Pod entièrement compatible PSA (avec tous les champs de la tâche 2 - non-root, seccomp, drop ALL, escalation false) sans le champ doit recevoir DENY de la paire exacte policy+binding ; `automountServiceAccountToken: false` doit recevoir ALLOW ; `automountServiceAccountToken: true` doit de nouveau recevoir DENY de la même paire.<br/>• Après la création de la policy, les nouveaux Pods dans `psa-restricted-107` (y compris le `restricted-app` recréé) doivent eux-mêmes contenir `automountServiceAccountToken: false`, sinon la politique les rejettera. |
| Critères d'acceptation | • **Objets :** `ValidatingAdmissionPolicy require-no-automount-token` et son `ValidatingAdmissionPolicyBinding` existent, `validationActions` contient `Deny`, le Binding ne correspond qu'à `psa-restricted-107`. Il existe exactement un Binding pour cette policy dans le lab - `require-no-automount-token-binding` ; aucun Binding supplémentaire de cette policy n'est créé pour d'autres namespaces.<br/>• **Trois états :** le server-side dry-run d'un Pod compatible PSA sans `automountServiceAccountToken: false` est rejeté précisément par la paire `ValidatingAdmissionPolicy 'require-no-automount-token'` et `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` (et non par le message PSA `violates PodSecurity` ni par une autre policy) ; le Pod avec `automountServiceAccountToken: false` est accepté, et le Pod avec `automountServiceAccountToken: true` est rejeté par la même paire exacte.<br/>• **Couverture de tous les Pods :** la policy couvre tous les Pods sélectionnés par ses `resourceRules`, à l'intérieur de `psa-restricted-107`. N'ajoutez pas `spec.matchConditions`, `matchConstraints.objectSelector` ni `matchConstraints.namespaceSelector` à la `ValidatingAdmissionPolicy`, ni `objectSelector` au Binding `matchResources` - ils restreignent la coverage à une partie des Pods, et un workload pourra échapper à la vérification par label ou par condition de la requête.<br/>• **Namespace scope :** défini uniquement par le Binding `matchResources.namespaceSelector`, lié exactement à `psa-restricted-107` ; le selector ne contient pas de conditions sur d'autres clés de namespace-label et limite à lui seul sans ambiguïté le scope à ce namespace.<br/>• **CEL :** la validation ne contient pas d'exceptions par nom/labels/annotations du Pod, user/request, `namespaceObject`, `params`, `variables` ou autres champs : la décision ne dépend que de `object.spec.automountServiceAccountToken` (toute forme CEL correcte est admissible, y compris la syntaxe optional `object.spec.?automountServiceAccountToken.orValue(true) == false`). `spec.auditAnnotations` est absent ou vide : ses CEL expressions distinctes peuvent influer sur l'admission via `failurePolicy`, c'est pourquoi l'admission control n'est défini que par `spec.validations`. `variables` et `paramKind` ne sont pas utilisés.<br/>• **Resource scope :** `matchConstraints.resourceRules` limitent la policy exactement à `core/v1 pods` pour les opérations `CREATE` et `UPDATE`, sans `resourceNames` ; `scope` est absent, vaut `*` ou `Namespaced`, mais pas `Cluster` ; `excludeResourceRules` ne sont pas utilisés. Le Binding ne restreint pas le resource/operation scope via ses propres `resourceRules`/`excludeResourceRules`.<br/>• Cela permet de démontrer le boolean contract complet par trois états `missing / false / true`, et non par quelques exemples de workload choisis. |

<details>
<summary>💡 Indice pour la tâche 6</summary>

Le Pod de test pour cette tâche doit être ENTIÈREMENT compatible PSA (tous les champs de la tâche 2), sauf l'absence de `automountServiceAccountToken: false` - si le Pod de test enfreint à la fois PSS et votre nouvelle policy, vous ne pourrez pas démontrer que c'est VOTRE policy qui a agi, et non le PSA intégré. Un `ValidatingAdmissionPolicyBinding` sans `matchResources.namespaceSelector` s'appliquera à TOUT le cluster - limitez obligatoirement le scope EXACTEMENT à un seul namespace `psa-restricted-107` (par exemple via `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}`), et non via `matchExpressions` avec plusieurs valeurs, où `psa-restricted-107` n'est qu'un parmi plusieurs namespaces correspondants : si votre selector correspond par accident aussi à `psa-observe-107`, la même règle commencera à agir de façon inattendue là aussi.
</details>

<details>
<summary>🔍 Vérifiez-vous avant `check_result`</summary>

Baseline - AVANT la création de VAP/Binding, le même Pod compatible PSA, mais sans l'automount opt-out,
doit passer (PSA ne le rejette pas de lui-même, `automountServiceAccountToken` ne fait pas partie
de PSS) :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "baseline exit: $?"
```

Créez VAP + Binding et répétez le manifest sans le champ - maintenant la requête doit recevoir
DENY précisément de `ValidatingAdmissionPolicy 'require-no-automount-token'` via le binding
`require-no-automount-token-binding`, PAS de PSA. Ensuite, vérifiez les deux valeurs explicites :
`false` doit passer, et `true` doit recevoir DENY de la même paire exacte.

```bash
kubectl apply -f require-no-automount-token.yaml   # vos VAP + Binding

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount
  namespace: psa-restricted-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# attendu : ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Avec le même manifest compatible PSA, définissez `automountServiceAccountToken: false` - la requête
doit passer :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-false
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: false
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# attendu : pod/self-check-automount-false created (ou server-side dry-run success)
```

Maintenant, définissez `automountServiceAccountToken: true` - la requête doit de nouveau être rejetée
par exactement la même policy et le même binding :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-true
  namespace: psa-restricted-107
spec:
  automountServiceAccountToken: true
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
# attendu : ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Enfin, le plus important - vérifiez la LIMITE du scope, et pas seulement le denial lui-même : le même
manifest (sans l'automount opt-out), mais dans le namespace `psa-observe-107`, doit PASSER - s'il
est lui aussi rejeté, c'est que votre `namespaceSelector` correspond à plus d'un namespace :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: self-check-automount-other-ns
  namespace: psa-observe-107
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
EOF
echo "exit code in psa-observe-107: $?"
# attendu : 0 (pas denied) - sinon le scope du binding est trop large
```
</details>

---

| **7** | **Controller-driven admission denial : diagnostic via les ReplicaSet events** |
| :---: | :--- |
| Ce qu'on fait | Dans le namespace vide `psa-controller-107`, créez un Deployment `controller-app` (label `app=controller-app`, replicas=1) avec un Pod template simple sans hardening (par exemple `busybox:1.36`, `sleep 3600`, sans `securityContext`) - il doit démarrer avec succès, PSA ne gêne pas encore. Activez ensuite `pod-security.kubernetes.io/enforce=restricted` et `enforce-version=v1.36` sur ce namespace (le Pod déjà existant continuera à fonctionner - PSA ne touche pas aux objets déjà créés). Supprimez le Pod actuel : le ReplicaSet essaiera de créer un remplaçant, et maintenant l'admission le rejettera. Vérifiez la cause via `kubectl -n psa-controller-107 describe rs` et `kubectl -n psa-controller-107 get events` - il y aura un `FailedCreate` avec le texte `violates PodSecurity "restricted:v1.36"`. Corrigez le Pod template du Deployment (ajoutez les mêmes champs de hardening que dans la tâche 2 : non-root, `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`) et attendez que le ReplicaSet crée avec succès un nouveau Pod qui passe. |
| Critères d'acceptation | Dans le namespace, l'enforce `restricted:v1.36` est actif ; le Pod template du Deployment est entièrement conforme au PSS `restricted` ; après la suppression du Pod actuel, le ReplicaSet crée réellement un nouveau Pod Ready sous l'enforce-mode actuel (pas simplement « l'objet existe » - on vérifie par une suppression en direct et une recréation). |

<details>
<summary>💡 Indice pour la tâche 7</summary>

L'ordre est important : d'abord le Deployment sans hardening (passe, PSA n'est pas encore enforce), puis le
label enforce=restricted sur le namespace (le Pod existant ne souffrira pas), puis `kubectl
delete pod -l app=controller-app` - c'est là que le ReplicaSet va se heurter à l'admission deny.
Si vous ne supprimez pas le Pod à la main, vous ne verrez pas du tout le refus tant qu'aucun reschedule ne se
produit naturellement. Il faut corriger précisément le `spec.template` du Deployment (`kubectl
edit deployment controller-app` ou `kubectl apply` avec le manifest corrigé), et non le
label du namespace - annuler l'enforce n'est pas la solution de cette tâche.
</details>

---

## Vérification

Sur la machine de travail, exécutez :

```bash
check_result
```

La vérification contient Init et sept tâches indépendantes. Elle exécute en plus un
server-side dry-run d'un Pod non sûr, l'absence d'un « mauvais » Pod permanent dans le
namespace restricted est donc un résultat attendu et correct. Dans la tâche 7, le checker supprime lui-même le
Pod actuel `controller-app` et vérifie que le ReplicaSet recrée réellement un Pod Ready -
il n'accepte pas comme preuve le texte des events.

## Solution

Solution de référence : [worker/files/solutions/1_FR.MD](worker/files/solutions/1_FR.MD)

## Suppression

```bash
TASK=107 make delete_cks_task
```

## Note sur la version de PSA et l'observabilité du mode audit

Le lab fige volontairement les PSA labels sur `v1.36`, car le cluster de lab lui-même fonctionne
sur Kubernetes 1.36.0. Au 2026-09-06, le blueprint officiel de CKS est orienté sur Kubernetes
`v1.35` ; c'est donc une configuration pédagogique **forward-looking**, et non une affirmation sur la version de
l'examen. Pour vous préparer à l'examen actuel, remplacez les suffixes `*-version` par `v1.35` et
comparez le comportement avec la documentation de cette version.

Le mode `audit` ajoute à l'**audit event de kube-apiserver** l'annotation
`pod-security.kubernetes.io/audit-violations` pour le Pod fautif. L'infrastructure de lab
ne configure ni ne fournit d'audit-log sink, donc cette annotation ne peut pas être lue ici via `kubectl`. La
preuve observable dans la tâche 4 est l'avertissement de PSA
(`Warning: ... would violate PodSecurity "baseline"`) lors de l'admission server-side et la création
réussie du Pod sans `enforce` ; l'audit mode est expliqué, mais son annotation de log n'est pas vérifiée
par ce lab.
