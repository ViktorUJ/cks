[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 - solution de référence : Pod Security Admission et read-only root filesystem

> Exécutez les commandes sur la machine de travail. Le contexte `cluster1-admin@cluster1` est déjà
> configuré. Les namespaces `psa-restricted-107`, `psa-observe-107` et `psa-controller-107` ont été créés par le script
> de démarrage, mais n'ont volontairement pas de PSA labels.

## 1. Enforce restricted et vérification du refus

PSA applique les Pod Security Standards d'après les labels du namespace. Figeons la version
du standard, afin que le comportement ne change pas avec une future mise à jour de Kubernetes :

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

Vérifions l'admission sans enregistrer l'objet dangereux. `hostNetwork` est interdit par le niveau
`restricted`, la commande doit donc se terminer par l'erreur `violates PodSecurity` :

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-by-restricted
  namespace: psa-restricted-107
spec:
  hostNetwork: true
  containers:
  - name: unsafe
    image: busybox:1.36
    command: ["sh", "-c", "sleep 5"]
YAML
```

## 2 et 5. Hardened Pod et emptyDir inscriptible

Créez le Pod directement dans sa forme sûre définitive. Le niveau `restricted` exige
non-root, seccomp, interdiction d'escalation et retrait des capabilities. Le read-only root filesystem
réduit les conséquences d'une écriture dans le conteneur ; il ne reste à l'application que `/tmp` dans un
`emptyDir`.

```yaml
# restricted-app.yaml
apiVersion: v1
kind: Pod
metadata:
  name: restricted-app
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
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
      seccompProfile:
        type: RuntimeDefault
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir:
      medium: Memory
```

```bash
kubectl apply -f restricted-app.yaml
kubectl get pod restricted-app -n psa-restricted-107
```

Démontrez les deux issues par un appel en direct, et pas seulement en lisant le YAML : le conteneur fonctionne sous
`runAsUser: 1000` avec un root read-only, donc l'écriture en dehors de `/tmp` doit se terminer par
une erreur du système de fichiers, et l'écriture dans l'`emptyDir` monté - réussir :

```bash
kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'touch /root-write-test.txt'
# touch: /root-write-test.txt: Read-only file system

kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt'
# probe
```

Si `restricted-app` a déjà été créé sans read-only filesystem, le champ du Pod ne peut pas être modifié ;
supprimez-le et recréez-le (si vous le faites déjà après la tâche 6, ajoutez au `spec`
le champ `automountServiceAccountToken: false` - sinon la politique de la tâche 6 rejettera le Pod) :

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. Audit et warn pour baseline

Ces modes n'interdisent pas la requête. `warn` renvoie un avertissement au client, et `audit`
ajoute à l'audit event de l'API server l'annotation
`pod-security.kubernetes.io/audit-violations`. Pour une adoption progressive, ne définissez pas
`enforce` dans le namespace d'observation :

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

> **Réserve de version.** `v1.36` est figée pour Kubernetes 1.36.0 dans cette infrastructure
> pédagogique. Au 2026-09-06, le CKS officiel est orienté sur `v1.35` ; c'est un
> exemple forward-looking, et pour vous préparer à l'examen, utilisez `*-version=v1.35`.

> **Limite de la preuve d'audit.** Le lab ne configure pas d'audit-log sink, c'est pourquoi
> `pod-security.kubernetes.io/audit-violations` ne peut pas être extrait par la commande `kubectl`.
> Le résultat réellement vérifiable ci-dessous est le PSA Warning et l'admission réussie ; l'audit
> annotation est expliquée, mais n'est pas un artefact vérifiable de cette infrastructure.

## 4. S'assurer que warn/audit ne bloquent pas le Pod

Ce Pod enfreint baseline à cause de `hostNetwork`, mais il est accepté, parce que dans le namespace
il n'y a pas d'`enforce`. `kubectl apply` affichera l'avertissement de PSA ; ne l'ignorez pas lors de
la migration d'un workload de production.

```yaml
# baseline-audit-sample.yaml
apiVersion: v1
kind: Pod
metadata:
  name: baseline-audit-sample
  namespace: psa-observe-107
spec:
  hostNetwork: true
  containers:
  - name: legacy
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f baseline-audit-sample.yaml
kubectl get pod baseline-audit-sample -n psa-observe-107
kubectl get namespace psa-restricted-107 --show-labels
kubectl get namespace psa-observe-107 --show-labels
```

## 6. Native ValidatingAdmissionPolicy sans Kyverno/Gatekeeper

PSA `restricted` exige déjà `allowPrivilegeEscalation: false` et `capabilities.drop`
contenant `ALL` - la tâche 2 montre précisément cela, et c'est une partie intégrée du Pod Security
Standard, et non une lacune. Mais PSS `restricted` **ne vérifie pas** `automountServiceAccountToken` :
un Pod peut recevoir discrètement un ServiceAccount token monté et passer entièrement PSA. Pour
ce control distinct, réellement non couvert, une `ValidatingAdmissionPolicy` custom est précisément de mise.

```yaml
# require-no-automount-token.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-no-automount-token
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      operations: ["CREATE", "UPDATE"]
      resources: ["pods"]
  validations:
  - expression: >-
      has(object.spec.automountServiceAccountToken) &&
      object.spec.automountServiceAccountToken == false
    message: "spec.automountServiceAccountToken must be explicitly set to false"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-no-automount-token-binding
spec:
  policyName: require-no-automount-token
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: psa-restricted-107
```

```bash
kubectl apply -f require-no-automount-token.yaml
kubectl get validatingadmissionpolicy,validatingadmissionpolicybinding
```

Démontrez les trois états via server-side dry-run, sans enregistrer de Pod permanent. Le Pod sans
le champ doit recevoir DENY de la paire exacte policy + binding, `false` doit passer, et
`true` doit recevoir DENY de la même paire. Le premier Pod
est entièrement conforme à PSA `restricted` (non-root, seccomp, `allowPrivilegeEscalation:
false`, `capabilities.drop: ["ALL"]`) - PSA l'aurait lui-même accepté, c'est pourquoi le refus doit
venir précisément de la nouvelle policy, et non de `violates PodSecurity` :

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-unsafe-check
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
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

Le même Pod avec `automountServiceAccountToken: false` ajouté doit passer :

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-safe-check
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
YAML
```

La valeur explicite `true` doit elle aussi être rejetée par la même policy et le même binding :

```bash
kubectl apply --dry-run=server -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: vap-explicit-true-check
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
YAML
# Error from server: ... ValidatingAdmissionPolicy 'require-no-automount-token'
# with binding 'require-no-automount-token-binding' denied request: ...
```

`Binding.matchResources.namespaceSelector` limite la policy uniquement à `psa-restricted-107` :
les Pods des autres namespaces (par exemple `psa-observe-107`) ne sont pas vérifiés par cette règle et ne
reçoivent pas de Deny superflu.

## 7. Controller-driven admission denial

D'abord un Deployment simple, non hardened - PSA n'est pas encore enforce, tout passe :

```bash
kubectl -n psa-controller-107 create deployment controller-app --image=busybox:1.36 -- sh -c "sleep 3600"
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

Nous activons enforce - le Pod existant n'est pas touché :

```bash
kubectl label namespace psa-controller-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
kubectl -n psa-controller-107 get pod
# controller-app-xxxx est toujours Running - PSA n'agit pas sur les objets déjà existants
```

Nous supprimons le Pod - le ReplicaSet essaie de créer un remplaçant et reçoit un refus :

```bash
kubectl -n psa-controller-107 delete pod -l app=controller-app
kubectl -n psa-controller-107 get events --sort-by=.lastTimestamp | tail -5
# ... FailedCreate ... violates PodSecurity "restricted:v1.36": ...
kubectl -n psa-controller-107 get deploy controller-app
# controller-app   0/1     1            0           ...   <- READY 0/1, AVAILABLE 0
```

Nous réparons le template - nous ajoutons les mêmes champs de hardening que dans la tâche 2 :

```bash
kubectl -n psa-controller-107 edit deployment controller-app
```

Dans `spec.template.spec`, remplacez la ligne `securityContext: {}` par le bloc ci-dessous, et dans le conteneur `busybox`
(le nom du conteneur est `busybox`, créé par `kubectl create deployment`) ajoutez-lui son propre `securityContext` :

```yaml
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: busybox
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
```

Enregistrez et attendez le rollout :

```bash
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

```
deployment "controller-app" successfully rolled out
```

```bash
check_result
```
