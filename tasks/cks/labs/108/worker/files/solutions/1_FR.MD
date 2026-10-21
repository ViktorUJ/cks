[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 - solution de référence : Kyverno admission policies

> Toutes les commandes s'exécutent sur la machine de travail. Le contexte est déjà configuré ; le namespace
> `policy-108` a été créé par le script de démarrage. Installez d'abord Kyverno et attendez le
> webhook : sinon les policies basées sur CEL suivantes ne vérifieront pas les requêtes d'admission.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. Installer Kyverno

Sur le worker est préparé un installer figé : il installe le Helm chart de Kyverno
`3.9.0` (Kyverno `1.19`) dans le namespace `kyverno`. On peut le consulter avant de le lancer.

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
```

Attendez qu'au moins un Deployment dans `kyverno` ait `AVAILABLE > 0`.

> **Migration note.** Les anciens exemples de `kyverno.io/v1` `Policy`/`ClusterPolicy` ne restent
> utiles que pour la maintenance de clusters existants. Dans Kyverno `1.19`, ils sont deprecated,
> et leur suppression est prévue dans `1.20`. Les nouvelles policy de ce lab utilisent
> `policies.kyverno.io/v1`.

## 2. Interdire le tag `latest`

Créez une `ValidatingPolicy` en mode `Deny`. La règle vérifie les trois listes de conteneurs -
`containers`, `initContainers` et `ephemeralContainers` : sinon, une image interdite peut facilement être
glissée via un init- ou ephemeral-container, et le Pod lui-même passera quand même l'admission.

```yaml
# deny-latest-tag.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: deny-latest-tag
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must use an explicit non-latest tag or a digest.
    expression: >-
      variables.images.all(image,
        image.contains('@') ||
        (image.matches('^(?:.*/)?[^/:]+:[^/]+$') && !image.endsWith(':latest')))
```

```bash
kubectl apply -f deny-latest-tag.yaml
```

La tâche autorise DEUX formes d'image reference - non-latest tag OU digest. Vérifiez
explicitement que la forme digest passe (et pas seulement qu'un versioned tag passe) - sinon il est facile
d'écrire une policy qui rejette par accident TOUTES les digest references :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: digest-pinned-ok
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause@sha256:5a92cb1de40c9c50e1c72e83bf35b9b32ce88e0d1b93f5e2727d97a44c176f56
EOF
# attendu : succès (aucune erreur d'admission)
```

Assurez-vous que le traitement du tag tient compte des deux-points dans le port du registry : `registry.example:5000/app`
ne contient pas d'image tag et doit être rejeté comme latest implicite. Le digest doit être
accepté aussi dans les autres listes de conteneurs - par exemple, dans `initContainers` et via
`kubectl debug --image=...` pour `ephemeralContainers`.

## 3. Exiger `runAsNonRoot`

La politique exige précisément la valeur `true` dans le `securityContext` au niveau du Pod ; la valeur
implicite et `false` ne passent pas. De plus, sont interdits `runAsUser: 0` au niveau du
Pod et les container-level overrides `runAsNonRoot: false` / `runAsUser: 0` dans les
trois container lists, sinon le securityContext au niveau du container pourra redéfinir le
`runAsNonRoot: true` au niveau du Pod et lancer un processus root.

```yaml
# require-run-as-non-root.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-run-as-non-root
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  validations:
  - message: Pod and every container must have an effective non-root security context.
    expression: >-
      has(object.spec.securityContext) &&
      object.spec.securityContext.?runAsNonRoot.orValue(false) &&
      object.spec.securityContext.?runAsUser.orValue(1) != 0 &&
      object.spec.containers.all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?initContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0)) &&
      object.spec.?ephemeralContainers.orValue([]).all(c,
        !has(c.securityContext) ||
        (c.securityContext.?runAsNonRoot.orValue(true) &&
         c.securityContext.?runAsUser.orValue(1) != 0))
```

```bash
kubectl apply -f require-run-as-non-root.yaml
```

## 4. N'autoriser que les registry approuvés

Sont autorisés `registry.k8s.io` et le chemin organisationnel dédié `ghcr.io/cks-lab`. CEL
réunit les trois container lists et applique un seul allowlist à chaque image.

```yaml
# allow-approved-registries.yaml
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: allow-approved-registries
spec:
  validationActions: [Deny]
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE, UPDATE]
      resources: [pods, pods/ephemeralcontainers]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  variables:
  - name: images
    expression: >-
      object.spec.containers.map(c, c.image)
      + object.spec.?initContainers.orValue([]).map(c, c.image)
      + object.spec.?ephemeralContainers.orValue([]).map(c, c.image)
  validations:
  - message: Images must come from registry.k8s.io or ghcr.io/cks-lab.
    expression: >-
      variables.images.all(image,
        image.startsWith('registry.k8s.io/') ||
        image.startsWith('ghcr.io/cks-lab/'))
```

```bash
kubectl apply -f allow-approved-registries.yaml
```

Vérification sans créer de Pod et sans image pull. `docker.io` n'est qu'UNE valeur
untrusted concrète ; vérifiez que la policy est bien un ALLOWLIST (interdit N'IMPORTE QUEL
registry sauf les deux autorisés), et pas simplement une denylist de `docker.io` par la chaîne littérale -
sinon une image unqualified, un autre registry tiers ou un host d'orthographe proche passeront
facilement à côté :

Les positive controls doivent couvrir les deux prefix autorisés (`registry.k8s.io/` et
`ghcr.io/cks-lab/`) dans `containers`, `initContainers` et `ephemeralContainers` ; ne
limitez pas l'un des registry aux seuls conteneurs ordinaires.

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-unqualified-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-quay-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: quay.io/prometheus/busybox:v0.24.0
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-lookalike-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io.evil.example/pause:3.10
EOF
```

Les quatre doivent être rejetés. Le premier Pod ci-dessous enfreint la règle avec le conteneur
principal, le second - uniquement avec `initContainers` ; les deux doivent être rejetés :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-registry-main
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: docker.io/library/busybox:1.36
EOF

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: rejected-init-registry
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  initContainers:
  - name: init
    image: docker.io/library/busybox:1.36
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
```

Les deux commandes doivent se terminer par une erreur de l'admission policy. Pour une tentative explicite de contournement via
`ephemeralContainers`, créez un Pod autorisé, puis exécutez `kubectl debug` d'abord avec
`docker.io/library/busybox:1.36` (on attend un denial), puis avec
`registry.k8s.io/e2e-test-images/busybox:1.36-1` (on attend un succès). C'est précisément
`pods/ephemeralcontainers` dans `matchConstraints` qui protège l'update du subresource.

## 5. Optionnel : mutation d'un label

Cette `MutatingPolicy` ne rejette pas le Pod, mais ajoute un label via CEL
`ApplyConfiguration` - mais seulement si le label n'est pas encore défini. La tâche exige précisément une
sémantique de defaulting (« s'il est absent ») : un Pod qui porte déjà ce label avec une AUTRE
valeur (par exemple, d'un autre propriétaire/outil) ne doit pas le recevoir
écrasé de force.

```yaml
# add-kyverno-managed-label.yaml
apiVersion: policies.kyverno.io/v1
kind: MutatingPolicy
metadata:
  name: add-kyverno-managed-label
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: [v1]
      operations: [CREATE]
      resources: [pods]
  matchConditions:
  - name: policy-108-only
    expression: request.namespace == 'policy-108'
  mutations:
  - patchType: ApplyConfiguration
    applyConfiguration:
      expression: >-
        has(object.metadata.labels) &&
        'security.cks.io/managed-by' in object.metadata.labels
        ? Object{}
        : Object{
            metadata: Object.metadata{
              labels: {"security.cks.io/managed-by": "kyverno"}
            }
          }
```

```bash
kubectl apply -f add-kyverno-managed-label.yaml
kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check
  namespace: policy-108
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# attendu : kyverno

kubectl apply --dry-run=server -o json -f - <<'EOF' \
  | jq -r '.metadata.labels["security.cks.io/managed-by"]'
apiVersion: v1
kind: Pod
metadata:
  name: mutation-check-existing-label
  namespace: policy-108
  labels:
    security.cks.io/managed-by: external
spec:
  securityContext:
    runAsNonRoot: true
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# attendu : external (la mutation N'écrase PAS la valeur déjà définie)
```

Exécutez `check_result`. L'étape 5 est affichée dans la vérification, mais elle est optionnelle : l'absence de la
mutation policy ne doit pas annuler la réussite des quatre premières étapes.

## 6. ImagePolicyWebhook : backend externe

Contrairement aux tâches 1-5, la décision sur l'image est ici prise par un backend HTTPS externe via l'
API `ImageReview`, et non par une expression CEL à l'intérieur de Kyverno. La documentation upstream
d'ImagePolicyWebhook exige explicitement que la backend connection utilise TLS ("It is
required that the backend communicate over TLS"), c'est pourquoi nous utilisons un certificat
auto-signé, et non HTTP.

Le backend est déjà préparé sur la machine de travail :

```bash
cat /opt/image-policy-backend/server.py
```

Créez le namespace et le ConfigMap avec le code du backend :

```bash
kubectl create namespace image-policy --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap image-policy-backend-src -n image-policy \
  --from-file=server.py=/opt/image-policy-backend/server.py \
  --dry-run=client -o yaml | kubectl apply -f -
```

Créez le Service **avant** le Deployment - il faut le `ClusterIP` pour le SAN correct dans le
certificat :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  selector:
    app: image-policy-backend
  ports:
  - port: 8443
    targetPort: 8443
EOF

BACKEND_IP=$(kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.clusterIP}')
echo "$BACKEND_IP"
```

Émettez un certificat auto-signé avec ce `ClusterIP` dans le SAN et enregistrez-le dans un Secret :

```bash
workdir=$(mktemp -d)
openssl req -x509 -nodes -newkey rsa:2048 -days 3 \
  -keyout "$workdir/tls.key" -out "$workdir/tls.crt" \
  -subj "/CN=image-policy-backend" \
  -addext "subjectAltName=IP:${BACKEND_IP}"

kubectl create secret tls image-policy-backend-tls -n image-policy \
  --cert="$workdir/tls.crt" --key="$workdir/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
```

Déployez le Deployment, en montant à la fois le code et le certificat :

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: image-policy-backend
  namespace: image-policy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: image-policy-backend
  template:
    metadata:
      labels:
        app: image-policy-backend
    spec:
      containers:
      - name: backend
        image: python:3.12-slim
        command: ["python3", "/opt/image-policy/server.py"]
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: src
          mountPath: /opt/image-policy
        - name: tls
          mountPath: /opt/image-policy/tls
          readOnly: true
      volumes:
      - name: src
        configMap:
          name: image-policy-backend-src
      - name: tls
        secret:
          secretName: image-policy-backend-tls
EOF

kubectl rollout status deployment/image-policy-backend -n image-policy --timeout=90s
```

Copiez le certificat CA (ici auto-signé, donc le certificat du serveur est à la fois sa
propre CA) sur le `control-plane`, afin que kube-apiserver puisse vérifier la chaîne lors de la
connexion au backend, et entrez sur le nœud :

```bash
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
scp "$workdir/tls.crt" "$CP":/tmp/image-policy-ca.crt
rm -rf "$workdir"
echo "$BACKEND_IP"     # sera nécessaire sur le nœud
ssh "$CP"
sudo -i
```

Sur le `control-plane`, créez l'admission config et le kubeconfig pour le backend. Les chemins sont sur le disque **du
control-plane lui-même** :

```bash
# sur le control-plane (root)
mkdir /etc/kubernetes/image-policy
mv /tmp/image-policy-ca.crt /etc/kubernetes/image-policy/ca.crt

cat > /etc/kubernetes/image-policy/admission-config.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: ImagePolicyWebhook
  configuration:
    imagePolicy:
      kubeConfigFile: /etc/kubernetes/image-policy/kubeconfig
      allowTTL: 30
      denyTTL: 30
      retryBackoff: 500
      defaultAllow: false
EOF

BACKEND_IP=10.111.15.20     # saisissez le ClusterIP qu'a affiché "echo $BACKEND_IP"
cat > /etc/kubernetes/image-policy/kubeconfig <<EOF
apiVersion: v1
kind: Config
clusters:
- name: image-policy-backend
  cluster:
    certificate-authority: /etc/kubernetes/image-policy/ca.crt
    server: https://${BACKEND_IP}:8443/imagepolicy
users:
- name: kube-apiserver
contexts:
- name: image-policy
  context:
    cluster: image-policy-backend
    user: kube-apiserver
current-context: image-policy
EOF
```

Modifiez le static manifest **sur le `control-plane`** (vous êtes déjà dans la session root). Ne remplacez pas
l'`--enable-admission-plugins` existant en entier - ajoutez `ImagePolicyWebhook` à la valeur actuelle
(en général, `NodeRestriction` y est déjà), ajoutez `--admission-control-config-file` et
`--runtime-config`, montez le nouveau répertoire comme hostPath :

```bash
# sur le control-plane (root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# fragment de /etc/kubernetes/manifests/kube-apiserver.yaml sur le control-plane
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook   # ajoutez à la liste existante
    - --admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml
    - --runtime-config=imagepolicy.k8s.io/v1alpha1=true               # ajoutez, si runtime-config était déjà défini
    volumeMounts:
    - name: image-policy
      mountPath: /etc/kubernetes/image-policy
      readOnly: true
  volumes:
  - name: image-policy
    hostPath:
      path: /etc/kubernetes/image-policy
      type: DirectoryOrCreate
```

Après l'enregistrement, quittez le nœud ; le kubelet reprendra lui-même la modification du static Pod :

```bash
exit   # de root
exit   # du control-plane
```

Attendez le rétablissement de l'API :

```bash
until kubectl get --raw=/readyz 2>/dev/null | grep -q '^ok$'; do sleep 5; done
```

Vérifiez les deux cas :

```bash
kubectl run webhook-latest-must-fail --image=nginx:latest
# Error from server (Forbidden): pods "webhook-latest-must-fail" is forbidden:
# image policy webhook backend denied one or more images: Images using latest tag are not allowed

kubectl run webhook-pinned-ok --image=nginx:1.27.3
kubectl get pod webhook-pinned-ok
# STATUS: Running
```

`ImagePolicyWebhook` utilise le backend de `/opt/image-policy-backend/server.py` :
dans `default` et les autres namespace (sauf `policy-108`), il interdit le latest
explicite/implicite ; `policy-108` est entièrement contrôlé par les trois politiques Kyverno des tâches 2–4.
C'est une isolation de mécanismes de lab, et non un pattern universel de production.
L'annotation utilisateur `alpha.image-policy.k8s.io/break-glass` NE donne PAS l'autorisation :
les annotations d'ImageReview forwarding ne sont pas une vérification d'authenticité.

`defaultAllow: false` signifie fail-closed : si le backend est indisponible, les nouveaux Pod/image
sont interdits, et non autorisés. Vérifiez-le explicitement - mais ne scalez PAS
`image-policy-backend` à 0 réplique : `ImagePolicyWebhook` est un admission
plugin cluster-wide sans exception par namespace dans notre configuration, il vérifie donc aussi le Pod
du backend lui-même. Si vous retirez temporairement toutes les répliques, puis essayez de les remettre,
la création d'un NOUVEAU Pod backend passera ELLE-MÊME par le même ImagePolicyWebhook (à ce moment
indisponible) et sera rejetée avec un `defaultAllow: false` correct -
il en résulte un deadlock dont `kubectl rollout status` ne sortira pas. À la place,
déconnectez le Service du backend en changeant le `selector` pour une valeur inexistante - cela ne
crée ni ne supprime aucun Pod, cela retire seulement temporairement les `Endpoints` :

```bash
kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.selector}'
# enregistrez cette valeur pour la restaurer plus tard

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend-detached-for-probe"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C quand ENDPOINTS devient vide

kubectl run webhook-should-fail-closed --image="nginx:fail-closed-check-$(date +%s%N)"
# attendu : Forbidden - le backend est indisponible, defaultAllow:false interdit l'admission
# (nous utilisons un tag PAS ENCORE vu, et pas simplement la date en secondes, pour ne pas tomber sur
# le cache TTL de la réponse du backend pour ce même tag de la tentative précédente)

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C quand ENDPOINTS réapparaît - c'est le même Pod qu'avant le probe, aucune
# reconstruction/recréation n'a été nécessaire
```

C'est la même décision fail-closed de principe que celle décrite dans le chapitre 26 pour la
configuration de production d'ImagePolicyWebhook.

## 7. Gatekeeper : compléter le blocklist de Rego dans le ConstraintTemplate

Gatekeeper et le `ConstraintTemplate`/`Constraint` de départ (incomplets) sont déjà déployés
par le bootstrap du cluster dans un namespace distinct `gatekeeper-108` - c'est un troisième admission
engine distinct dans ce lab (après Kyverno et ImagePolicyWebhook), qui vérifie précisément la
compétence OPA/Rego. `gatekeeper-108` est isolé des tâches 1-5 de Kyverno (`policy-108`)
exprès : sinon le même Pod de test pourrait être rejeté à la fois par Kyverno et par
Gatekeeper, et l'origine du denial serait ambiguë. Regardez le Rego actuel :

```bash
kubectl get constrainttemplate k8sblockedregistries -o yaml
```

`spec.targets[].rego` déclare les registry bloqués par des faits distincts :

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
```

`very-bad-registry.test` n'y figure pas - c'est précisément cette ligne qu'il faut ajouter. Le `Constraint
deny-bad-registries` est déjà tout à fait correct et n'utilise pas du tout `spec.parameters` -
il n'est pas nécessaire de le modifier ; la correction se trouve PRÉCISÉMENT dans le Rego à l'intérieur du
`ConstraintTemplate`, et non dans le Constraint. Modifiez le template (par exemple `kubectl edit
constrainttemplate k8sblockedregistries`, ou `get -o yaml` → modification → `apply -f -`),
en ajoutant une nouvelle ligne sans supprimer les existantes :

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
blocked_registry("very-bad-registry.test")
```

Vérifiez les trois issues du server-side dry-run, sans créer de Pod permanent : le nouveau
registry doit être denied, l'ancien (déjà bloqué) doit rester denied (pas de régression),
celui de confiance doit passer :

```bash
kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-new-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: very-bad-registry.test/malicious/app:1.0
EOF
# attendu : Error from server ... admission webhook "validation.gatekeeper.sh" denied
# the request: [deny-bad-registries] image registry very-bad-registry.test is blocked
# by k8sblockedregistries

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-old-bad-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: untrusted-registry.example/app:1
EOF
# attendu : aussi Error from server ... - l'ancienne règle ne doit pas être perdue

kubectl apply --dry-run=server -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: gatekeeper-trusted-check
  namespace: gatekeeper-108
spec:
  containers:
  - name: app
    image: registry.k8s.io/pause:3.10
EOF
# attendu : succès (aucune erreur d'admission)
```

Assurez-vous que le refus est réellement venu de Gatekeeper (`validation.gatekeeper.sh`), et
non de l'une des `ValidatingPolicy` de Kyverno des tâches 2-4 - le message d'erreur nomme explicitement
le webhook et le nom de votre Constraint. Ne résolvez pas la tâche via `Constraint.spec.parameters`
- dans cette version de la policy, le Constraint ne les utilise pas du tout.

Exécutez `check_result`.
