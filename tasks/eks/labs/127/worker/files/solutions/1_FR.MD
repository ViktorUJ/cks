[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 127 - solution de référence (ValidatingAdmissionPolicy en CEL)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl est déjà configuré
sur le cluster (le kubeconfig est assemblé via `aws eks update-kubeconfig` au démarrage de
la machine).

## Tâche 1. Namespace `eks-127`

```bash
kubectl create namespace eks-127
```

## Tâche 2. La politique CEL en mode Audit laisse passer un pod avec `:latest`

Nous créons une `ValidatingAdmissionPolicy` et un `ValidatingAdmissionPolicyBinding` avec
`validationActions: ["Audit"]`. La politique s'applique uniquement au namespace `eks-127`
via un `namespaceSelector` (label `kubernetes.io/metadata.name`, que k8s place
automatiquement sur le namespace) :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-latest-tag
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, !c.image.endsWith(':latest'))"
      message: "le tag :latest est forbidden, indiquez une version d'image précise"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Audit"]
EOF
```

Nous vérifions que les deux objets sont en place :

```bash
kubectl get validatingadmissionpolicy disallow-latest-tag
kubectl get validatingadmissionpolicybinding disallow-latest-tag-binding
```

Maintenant nous créons un pod avec une image `:latest` en mode `Audit` - il doit être CRÉÉ,
car `Audit` ne fait qu'écrire la violation dans le log d'audit sans bloquer la requête :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: latest-audit-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

kubectl get pod latest-audit-pod -n eks-127
```

Le pod est créé même s'il viole la règle - c'est tout le sens d'`Audit` : tester la
politique sans risquer de casser la charge existante.

## Tâche 3. On passe en Deny - un pod avec `:latest` est refusé

Nous mettons à jour le Binding, en changeant uniquement `validationActions` :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: ["Deny"]
EOF
```

Nous essayons de créer un autre pod avec `:latest` - maintenant l'apiserver doit refuser la
requête :

```bash
mkdir -p /var/work/tests/artifacts/3
cat <<'EOF' | kubectl apply -f - 2> /var/work/tests/artifacts/3/denied.txt
apiVersion: v1
kind: Pod
metadata:
  name: latest-deny-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:latest
EOF

cat /var/work/tests/artifacts/3/denied.txt
```

Le fichier `denied.txt` doit contenir le message d'erreur de l'apiserver avec le texte de
la politique (les mots `latest` et `forbidden`). Le pod `latest-deny-pod` n'est PAS créé -
`kubectl get pod latest-deny-pod -n eks-127` renverra `NotFound`.

## Tâche 4. Un pod légitime avec un tag explicite passe même en Deny

La politique ne vérifie que `:latest`, donc un pod avec une version d'image précise passe
sans problème. Le tag `53833ea` est un vrai tag de commit dans `viktoruj/ping_pong`, il
existe et est construit pour amd64 et arm64. Il est important d'utiliser un tag existant :
l'admission ne regarde que la chaîne de l'image, donc un pod avec un tag inventé serait
tout de même créé et resterait bloqué en `ErrImagePull` - la politique n'aurait formellement
« pas gêné », mais il ne resterait rien pour vérifier cette affirmation :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tagged-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF

kubectl get pod tagged-pod -n eks-127
```

## Tâche 5. Seconde politique CEL : resources.requests obligatoire

Une autre `ValidatingAdmissionPolicy` directement en mode `Deny` - nous exigeons que chaque
conteneur ait `resources.requests` défini :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-resources-requests
spec:
  matchConstraints:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: eks-127
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "object.spec.containers.all(c, has(c.resources) && has(c.resources.requests))"
      message: "chaque conteneur doit avoir resources.requests défini"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: require-resources-requests-binding
spec:
  policyName: require-resources-requests
  validationActions: ["Deny"]
EOF
```

Un pod sans `requests` est refusé :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: no-requests-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
EOF
```

La commande renvoie une erreur d'admission, et `kubectl get pod no-requests-pod -n
eks-127` affichera `NotFound`. Un pod avec `requests` défini passe normalement :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: requests-ok-pod
  namespace: eks-127
spec:
  containers:
  - name: app
    image: viktoruj/ping_pong:53833ea
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
EOF

kubectl get pod requests-ok-pod -n eks-127
```

## Tâche 6. `failurePolicy: Fail` et la différence avec un webhook externe

Nous fixons explicitement `failurePolicy: Fail` sur la première politique (c'est la valeur
par défaut, mais nous la fixons explicitement) :

```bash
kubectl patch validatingadmissionpolicy disallow-latest-tag --type merge \
  -p '{"spec":{"failurePolicy":"Fail"}}'

kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.spec.failurePolicy}'
```

`failurePolicy` réagit à une erreur d'ÉVALUATION de l'expression CEL (par exemple, accéder
à un champ absent d'un objet issu d'une ancienne version d'API), pas à l'indisponibilité
d'un service externe. La `ValidatingAdmissionPolicy` intégrée n'a aucun webhook externe -
CEL est évalué directement dans l'apiserver, donc elle n'a pas le risque « le webhook n'a
pas répondu », propre à Kyverno et Gatekeeper (là, les règles
sont exécutées par un service séparé derrière un webhook, et s'il est indisponible,
`failurePolicy: Fail` fait mettre en file d'attente ou bloque les requêtes).

Nous enregistrons l'explication dans un artefact :

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/failurepolicy.txt <<'EOF'
failurePolicy sur une ValidatingAdmissionPolicy ne réagit qu'à une erreur d'évaluation de
l'expression CEL (par exemple, l'accès à un champ absent de l'objet), pas à
l'indisponibilité d'un service externe.

La ValidatingAdmissionPolicy intégrée n'a aucun webhook externe : l'expression CEL est
évaluée directement dans l'apiserver, sans aucun appel réseau vers l'extérieur. C'est
pourquoi il n'y a ici aucun risque « le webhook n'a pas répondu »,
caractéristique de Kyverno et Gatekeeper, où les règles sont exécutées par un service
séparé derrière un webhook et où l'apiserver attend sa réponse.
EOF
cat /var/work/tests/artifacts/6/failurepolicy.txt
```

## Vérification rapide

```bash
check_result
```

Commandes utiles pour examiner l'état des politiques :

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl get validatingadmissionpolicy disallow-latest-tag -o yaml
```
