[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 127 - Referenzlösung (ValidatingAdmissionPolicy mit CEL)

Alle Befehle laufen auf der Worker-Maschine über SSH. kubectl ist bereits auf dem Cluster
konfiguriert (die kubeconfig wird beim Booten der Maschine über
`aws eks update-kubeconfig` zusammengestellt).

## Aufgabe 1. Namespace `eks-127`

```bash
kubectl create namespace eks-127
```

## Aufgabe 2. Die CEL-Policy im Audit-Modus lässt einen Pod mit `:latest` durch

Wir erstellen eine `ValidatingAdmissionPolicy` und ein `ValidatingAdmissionPolicyBinding`
mit `validationActions: ["Audit"]`. Die Policy gilt nur für den Namespace `eks-127` über
einen `namespaceSelector` (Label `kubernetes.io/metadata.name`, das k8s automatisch auf
dem Namespace setzt):

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
      message: "das Tag :latest ist запрещён, geben Sie eine konkrete Image-Version an"
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

Wir prüfen, dass beide Objekte vorhanden sind:

```bash
kubectl get validatingadmissionpolicy disallow-latest-tag
kubectl get validatingadmissionpolicybinding disallow-latest-tag-binding
```

Jetzt erstellen wir einen Pod mit einem `:latest`-Image im `Audit`-Modus - er sollte
ERSTELLT werden, da `Audit` den Verstoß nur ins Audit-Log schreibt, ohne die Anfrage zu
blockieren:

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

Der Pod wird erstellt, obwohl er die Regel verletzt - das ist genau der Sinn von `Audit`:
die Policy ausprobieren, ohne zu riskieren, die bestehende Last zu zerstören.

## Aufgabe 3. Umschalten auf Deny - ein Pod mit `:latest` wird abgelehnt

Wir aktualisieren das Binding und ändern nur `validationActions`:

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

Wir versuchen, einen weiteren Pod mit `:latest` zu erstellen - jetzt sollte der apiserver
die Anfrage ablehnen:

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

Die Datei `denied.txt` muss die Fehlermeldung des apiservers mit dem Text der Policy
enthalten (die Wörter `latest` und `запрещён`). Der Pod `latest-deny-pod` wird dabei NICHT
erstellt - `kubectl get pod latest-deny-pod -n eks-127` gibt `NotFound` zurück.

## Aufgabe 4. Ein legitimer Pod mit explizitem Tag kommt auch bei Deny durch

Die Policy prüft nur `:latest`, daher kommt ein Pod mit einer konkreten Image-Version
problemlos durch. Das Tag `53833ea` ist ein echtes Commit-Tag in `viktoruj/ping_pong`, es
existiert und ist für amd64 und arm64 gebaut. Es ist wichtig, ein existierendes Tag zu
verwenden: die Admission schaut nur auf die Image-Zeichenkette, daher würde ein Pod mit
einem erfundenen Tag ebenfalls erstellt und würde in `ErrImagePull` hängen bleiben - die
Policy hätte formal "nicht gestört", aber es gäbe nichts mehr, womit man diese Behauptung
überprüfen könnte:

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

## Aufgabe 5. Zweite CEL-Policy: obligatorische `resources.requests`

Eine weitere `ValidatingAdmissionPolicy` direkt im `Deny`-Modus - wir fordern, dass jeder
Container `resources.requests` gesetzt hat:

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
      message: "jeder Container muss resources.requests gesetzt haben"
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

Ein Pod ohne `requests` wird abgelehnt:

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

Der Befehl liefert einen Admission-Fehler, und `kubectl get pod no-requests-pod -n
eks-127` zeigt `NotFound`. Ein Pod mit gesetztem `requests` kommt normal durch:

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

## Aufgabe 6. `failurePolicy: Fail` und der Unterschied zu einem externen Webhook

Wir setzen explizit `failurePolicy: Fail` auf der ersten Policy (das ist der Standardwert,
aber wir legen ihn explizit fest):

```bash
kubectl patch validatingadmissionpolicy disallow-latest-tag --type merge \
  -p '{"spec":{"failurePolicy":"Fail"}}'

kubectl get validatingadmissionpolicy disallow-latest-tag -o jsonpath='{.spec.failurePolicy}'
```

`failurePolicy` reagiert auf einen Fehler bei der AUSWERTUNG des CEL-Ausdrucks (zum
Beispiel den Zugriff auf ein Feld, das bei einer älteren API-Version nicht existiert), nicht
auf die Nichterreichbarkeit eines externen Dienstes. Die eingebaute
`ValidatingAdmissionPolicy` hat überhaupt kein externes Webhook - CEL wird direkt im
apiserver ausgewertet, daher hat sie nicht das Risiko "das Webhook hat nicht geantwortet",
das für Kyverno und Gatekeeper typisch ist (dort führt ein
separater Dienst hinter einem Webhook die Regeln aus, und wenn er nicht erreichbar ist,
reiht `failurePolicy: Fail` Anfragen ein oder blockiert sie).

Wir speichern die Erklärung in einem Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/6
cat > /var/work/tests/artifacts/6/failurepolicy.txt <<'EOF'
failurePolicy bei einer ValidatingAdmissionPolicy reagiert nur auf einen Fehler bei der
Auswertung des CEL-Ausdrucks (zum Beispiel den Zugriff auf ein im Objekt fehlendes Feld),
nicht auf die Nichterreichbarkeit eines externen Dienstes.

Die eingebaute ValidatingAdmissionPolicy hat überhaupt kein externes Webhook: der
CEL-Ausdruck wird direkt im apiserver ausgewertet, ohne jeden Netzwerkaufruf nach außen.
Deshalb gibt es hier nicht das Risiko "das Webhook hat nicht geantwortet",
das für Kyverno und Gatekeeper typisch ist, wo ein separater Dienst hinter einem
Webhook die Regeln ausführt und der apiserver auf dessen Antwort wartet.
EOF
cat /var/work/tests/artifacts/6/failurepolicy.txt
```

## Schnelle Prüfung

```bash
check_result
```

Nützliche Befehle zur Analyse des Policy-Zustands:

```bash
kubectl get validatingadmissionpolicy
kubectl get validatingadmissionpolicybinding
kubectl get validatingadmissionpolicy disallow-latest-tag -o yaml
```
