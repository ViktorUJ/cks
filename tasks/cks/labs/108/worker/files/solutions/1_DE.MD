[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 - Referenzlösung: Kyverno admission policies

> Alle Befehle werden auf der Arbeitsmaschine ausgeführt. Der Kontext ist bereits eingerichtet; der Namespace
> `policy-108` wurde vom Start-Skript erstellt. Installiere zuerst Kyverno und warte auf den
> webhook: Die nachfolgenden CEL-basierten policies prüfen sonst keine admission-Anfragen.

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
```

## 1. Kyverno installieren

Auf dem worker ist ein festgelegter installer vorbereitet: Er installiert den Helm chart von Kyverno
`3.9.0` (Kyverno `1.19`) in den Namespace `kyverno`. Du kannst ihn dir vor dem Start ansehen.

```bash
cat /usr/local/bin/install-kyverno
install-kyverno
kubectl get pods -n kyverno
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
```

Warte, bis mindestens ein Deployment in `kyverno` `AVAILABLE > 0` hat.

> **Migration note.** Alte Beispiele mit `kyverno.io/v1` `Policy`/`ClusterPolicy` bleiben nur
> bei der Betreuung bestehender Cluster nützlich. In Kyverno `1.19` sind sie deprecated,
> und in `1.20` ist die Entfernung geplant. Neue policies in diesem Lab verwenden
> `policies.kyverno.io/v1`.

## 2. Tag `latest` verbieten

Erstelle eine `ValidatingPolicy` im Modus `Deny`. Die Regel prüft alle drei Listen von Containern -
`containers`, `initContainers` und `ephemeralContainers`: Sonst lässt sich ein verbotenes Image leicht
über einen init- oder ephemeral container einschleusen, während der Pod selbst admission trotzdem besteht.

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

Die Aufgabe erlaubt ZWEI Formen einer image reference - non-latest tag ODER digest. Prüfe
explizit, dass die digest-Form durchgeht (und nicht nur, dass ein versionierter Tag durchgeht) - sonst lässt sich leicht
eine policy schreiben, die versehentlich ALLE digest references ablehnt:

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
# erwartet: Erfolg (kein admission-Fehler)
```

Stelle sicher, dass die Verarbeitung des Tags den Doppelpunkt im Registry-Port berücksichtigt: `registry.example:5000/app`
enthält keinen image tag und muss als implicit latest abgelehnt werden. Ein digest muss
auch in anderen Listen von Containern akzeptiert werden - zum Beispiel in `initContainers` und über
`kubectl debug --image=...` für `ephemeralContainers`.

## 3. `runAsNonRoot` verlangen

Die policy verlangt genau den Wert `true` im Pod-level `securityContext`; ein impliziter
Wert und `false` bestehen nicht. Zusätzlich sind `runAsUser: 0` auf Ebene des
Pods und container-level overrides `runAsNonRoot: false` / `runAsUser: 0` in allen
drei container lists verboten, sonst kann der container-level securityContext das
Pod-level `runAsNonRoot: true` überschreiben und einen root-Prozess starten.

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

## 4. Nur genehmigte Registries erlauben

Erlaubt sind `registry.k8s.io` und der dedizierte Organisationspfad `ghcr.io/cks-lab`. CEL
vereinigt alle drei container lists und wendet auf jedes Image dieselbe Allowlist an.

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

Prüfung ohne Erstellen eines Pods und ohne image pull. `docker.io` ist nur EIN konkreter
untrusted-Wert; prüfe, dass die policy tatsächlich eine ALLOWLIST ist (sie verbietet JEDE
Registry außer den beiden erlaubten) und nicht einfach eine Denylist von `docker.io` mit dem buchstäblichen String -
sonst gehen ein unqualified image, eine andere Drittanbieter-Registry oder ein ähnlich geschriebener Host leicht
vorbei.

Positive controls müssen beide erlaubten Präfixe (`registry.k8s.io/` und
`ghcr.io/cks-lab/`) in `containers`, `initContainers` und `ephemeralContainers` abdecken; beschränke
keine der Registries nur auf gewöhnliche Container:

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

Alle vier müssen abgelehnt werden. Der erste Pod unten verletzt die Regel mit dem Hauptcontainer,
der zweite - nur mit `initContainers`; beide müssen abgelehnt werden:

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

Beide Befehle müssen mit einem admission-policy-Fehler enden. Für einen expliziten Umgehungsversuch über
`ephemeralContainers` erstelle einen erlaubten Pod und führe dann `kubectl debug` zuerst mit
`docker.io/library/busybox:1.36` aus (erwartet wird denial), dann mit
`registry.k8s.io/e2e-test-images/busybox:1.36-1` (erwartet wird Erfolg). Genau
`pods/ephemeralcontainers` in `matchConstraints` schützt das subresource update.

## 5. Optional: mutation eines Labels

Diese `MutatingPolicy` lehnt den Pod nicht ab, sondern fügt ein Label über CEL
`ApplyConfiguration` hinzu - aber nur, wenn das Label noch nicht gesetzt ist. Die Aufgabe verlangt ausdrücklich
die defaulting-Semantik („falls es fehlt“): Ein Pod, der dieses Label bereits mit einem ANDEREN
Wert trägt (zum Beispiel von einem anderen Eigentümer/Werkzeug), darf es nicht
zwangsweise überschrieben bekommen.

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
# erwartet: kyverno

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
# erwartet: external (mutation überschreibt einen bereits gesetzten Wert NICHT)
```

Führe `check_result` aus. Aufgabe 5 wird in der Prüfung angezeigt, ist aber optional: Das Fehlen der
mutation policy beeinflusst die Wertung der Aufgaben 1-4, 6 und 7 nicht.

## 6. ImagePolicyWebhook: externes Backend

Anders als in den Aufgaben 1-5 trifft hier die Entscheidung über das Image ein externes HTTPS-Backend über die
API `ImageReview` und nicht ein CEL-Ausdruck innerhalb von Kyverno. Die Upstream-Dokumentation zu
ImagePolicyWebhook verlangt ausdrücklich, dass die Backend-Verbindung TLS verwendet ("It is
required that the backend communicate over TLS"), daher verwenden wir ein selbstsigniertes
Zertifikat und nicht HTTP.

Das Backend ist auf der Arbeitsmaschine bereits vorbereitet:

```bash
cat /opt/image-policy-backend/server.py
```

Erstelle den Namespace und die ConfigMap mit dem Code des Backends:

```bash
kubectl create namespace image-policy --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap image-policy-backend-src -n image-policy \
  --from-file=server.py=/opt/image-policy-backend/server.py \
  --dry-run=client -o yaml | kubectl apply -f -
```

Erstelle den Service **vor** dem Deployment - die `ClusterIP` wird für das richtige SAN im
Zertifikat gebraucht:

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

Stelle ein selbstsigniertes Zertifikat mit dieser `ClusterIP` im SAN aus und speichere es in einem Secret:

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

Rolle das Deployment aus und mounte dabei sowohl den Code als auch das Zertifikat:

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

Kopiere das CA-Zertifikat (hier self-signed, daher ist das Serverzertifikat selbst seine
eigene CA) auf die `control-plane`, damit der kube-apiserver die Kette beim
Verbinden mit dem Backend prüfen kann, und melde dich auf dem Node an:

```bash
CP=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')
scp "$workdir/tls.crt" "$CP":/tmp/image-policy-ca.crt
rm -rf "$workdir"
echo "$BACKEND_IP"     # wird auf dem Node gebraucht
ssh "$CP"
sudo -i
```

Erstelle auf der `control-plane` die admission config und die kubeconfig für das Backend. Die Pfade liegen auf der Platte der **control-plane
selbst**:

```bash
# auf der control-plane (root)
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

BACKEND_IP=10.111.15.20     # trage die ClusterIP ein, die "echo $BACKEND_IP" ausgegeben hat
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

Bearbeite das static manifest **auf der `control-plane`** (du bist bereits in der root-Sitzung). Ersetze nicht das
vorhandene `--enable-admission-plugins` vollständig - hänge `ImagePolicyWebhook` an den aktuellen
Wert an (gewöhnlich ist dort bereits `NodeRestriction`), füge `--admission-control-config-file` und
`--runtime-config` hinzu, mounte das neue Verzeichnis als hostPath:

```bash
# auf der control-plane (root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

```yaml
# Ausschnitt aus /etc/kubernetes/manifests/kube-apiserver.yaml auf der control-plane
spec:
  containers:
  - name: kube-apiserver
    command:
    - kube-apiserver
    - --enable-admission-plugins=NodeRestriction,ImagePolicyWebhook   # an die vorhandene Liste anhängen
    - --admission-control-config-file=/etc/kubernetes/image-policy/admission-config.yaml
    - --runtime-config=imagepolicy.k8s.io/v1alpha1=true               # ergänzen, falls runtime-config bereits gesetzt war
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

Verlasse nach dem Speichern den Node; das kubelet übernimmt die Änderung des static Pods selbst:

```bash
exit   # aus root
exit   # von der control-plane
```

Warte auf die Wiederherstellung der API:

```bash
until kubectl get --raw=/readyz 2>/dev/null | grep -q '^ok$'; do sleep 5; done
```

Prüfe beide Fälle:

```bash
kubectl run webhook-latest-must-fail --image=nginx:latest
# Error from server (Forbidden): pods "webhook-latest-must-fail" is forbidden:
# image policy webhook backend denied one or more images: Images using latest tag are not allowed

kubectl run webhook-pinned-ok --image=nginx:1.27.3
kubectl get pod webhook-pinned-ok
# STATUS: Running
```

`ImagePolicyWebhook` verwendet das Backend aus `/opt/image-policy-backend/server.py`:
In `default` und den übrigen Namespaces (außer `policy-108`) verbietet er explicit/implicit
latest; `policy-108` kontrollieren vollständig die drei Kyverno-Policies aus den Aufgaben 2–4.
Das ist eine Lab-Isolation der Mechanismen und kein universelles production pattern.
Die Benutzer-Annotation `alpha.image-policy.k8s.io/break-glass` gibt KEINE Erlaubnis:
Das Weiterleiten von ImageReview-Annotations ist keine Prüfung der Authentizität.

`defaultAllow: false` bedeutet fail-closed: Wenn das Backend nicht verfügbar ist, werden neue Pods/Images
verboten und nicht erlaubt. Prüfe das explizit - aber skaliere `image-policy-backend` NICHT auf 0 Replicas:
`ImagePolicyWebhook` ist ein cluster-wide admission
plugin ohne Ausnahme nach Namespace in unserer Konfiguration, daher prüft er auch den Pod
des Backends selbst. Wenn man vorübergehend alle Replicas entfernt und dann versucht, sie
zurückzubringen, durchläuft die Erstellung eines NEUEN Backend-Pods SELBST denselben (in diesem Moment
nicht verfügbaren) ImagePolicyWebhook und wird bei korrektem `defaultAllow: false` abgelehnt -
es entsteht ein Deadlock, aus dem `kubectl rollout status` nicht herauskommt. Trenne stattdessen
den Service vom Backend, indem du den `selector` auf einen nicht existierenden Wert änderst - das
erstellt und löscht keinen einzigen Pod, es entfernt nur vorübergehend die `Endpoints`:

```bash
kubectl get service image-policy-backend -n image-policy -o jsonpath='{.spec.selector}'
# speichere diesen Wert, um ihn später wiederherzustellen

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend-detached-for-probe"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C, wenn ENDPOINTS leer wird

kubectl run webhook-should-fail-closed --image="nginx:fail-closed-check-$(date +%s%N)"
# erwartet: Forbidden - das Backend ist nicht verfügbar, defaultAllow:false verbietet admission
# (wir verwenden einen NOCH NICHT gesehenen Tag und nicht einfach ein Datum in Sekunden, um nicht auf den
# TTL-Cache der Antwort des Backends für denselben Tag aus dem vorherigen Versuch zu stoßen)

kubectl patch service image-policy-backend -n image-policy \
  -p '{"spec":{"selector":{"app":"image-policy-backend"}}}'
kubectl get endpoints image-policy-backend -n image-policy -w
# Ctrl+C, wenn ENDPOINTS wieder erscheint - das ist derselbe Pod wie vor dem Test, es war kein Neuaufbau/keine
# Neuerstellung nötig
```

Das ist dieselbe grundsätzliche fail-closed-Entscheidung, die in [Kapitel 26 des Kurses](../../../../../course/26/de.md) für die
production-Konfiguration von ImagePolicyWebhook beschrieben ist.

## 7. Gatekeeper: Rego blocklist im ConstraintTemplate ergänzen

Gatekeeper und das anfängliche (unvollständige) `ConstraintTemplate`/`Constraint` sind bereits vom
bootstrap des Clusters in einem separaten Namespace `gatekeeper-108` ausgerollt - das ist eine separate, dritte
admission engine in diesem Lab (nach Kyverno und ImagePolicyWebhook), die gezielt die
OPA/Rego-Fertigkeit prüft. `gatekeeper-108` ist von den Kyverno-Aufgaben 1-5 (`policy-108`)
absichtlich isoliert: Sonst könnte derselbe Test-Pod gleichzeitig von Kyverno und
Gatekeeper abgelehnt werden, und die Quelle des denial wäre nicht eindeutig. Sieh dir das aktuelle Rego an:

```bash
kubectl get constrainttemplate k8sblockedregistries -o yaml
```

`spec.targets[].rego` deklariert die blockierten Registries über einzelne Fakten:

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
```

`very-bad-registry.test` ist nicht darunter - genau diese Zeile muss ergänzt werden. `Constraint
deny-bad-registries` ist bereits vollständig korrekt und verwendet `spec.parameters` überhaupt nicht -
es muss nicht bearbeitet werden; die Korrektur liegt GENAU im Rego innerhalb des
`ConstraintTemplate` und nicht im Constraint. Bearbeite das template (zum Beispiel `kubectl edit
constrainttemplate k8sblockedregistries`, oder `get -o yaml` → Änderung → `apply -f -`) und
füge die neue Zeile hinzu, ohne die vorhandenen zu löschen:

```rego
blocked_registry("untrusted-registry.example")
blocked_registry("docker-fake.test")
blocked_registry("very-bad-registry.test")
```

Prüfe alle drei Ergebnisse per server-side dry-run, ohne einen dauerhaften Pod zu erstellen: Die neue
Registry muss denied werden, die alte (bereits blockierte) - denied bleiben (keine Regression),
die vertrauenswürdige - durchgehen:

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
# erwartet: Error from server ... admission webhook "validation.gatekeeper.sh" denied
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
# erwartet: ebenfalls Error from server ... - die alte Regel darf nicht verloren gehen

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
# erwartet: Erfolg (kein admission-Fehler)
```

Stelle sicher, dass die Ablehnung tatsächlich von Gatekeeper kam (`validation.gatekeeper.sh`) und
nicht von einer der Kyverno `ValidatingPolicy` aus den Aufgaben 2-4 - die Fehlermeldung nennt ausdrücklich
den webhook und den Namen deines Constraints. Löse die Aufgabe nicht über `Constraint.spec.parameters` -
in dieser Version der policy verwendet das Constraint sie überhaupt nicht.

Führe `check_result` aus.
