[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 107 - Referenzlösung: Pod Security Admission und read-only root filesystem

> Führe die Befehle auf der Arbeitsmaschine aus. Der Kontext `cluster1-admin@cluster1` ist bereits
> eingerichtet. Die Namespaces `psa-restricted-107`, `psa-observe-107` und `psa-controller-107` wurden vom Startskript
> erstellt, haben aber absichtlich keine PSA-Labels.

## 1. Enforce restricted und Prüfung der Ablehnung

PSA wendet die Pod Security Standards anhand der Labels des Namespace an. Wir legen die Version
des Standards fest, damit sich das Verhalten mit einem künftigen Kubernetes-Update nicht ändert:

```bash
kubectl label namespace psa-restricted-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
```

Wir prüfen die admission, ohne das gefährliche Objekt zu speichern. `hostNetwork` ist durch die Stufe
`restricted` verboten, daher muss der Befehl mit dem Fehler `violates PodSecurity` enden:

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

## 2 und 5. Hardened Pod und beschreibbares emptyDir

Erstelle den Pod gleich in der endgültigen sicheren Form. Die Stufe `restricted` verlangt
non-root, seccomp, das Verbot von escalation und das Entfernen von capabilities. Ein read-only root filesystem
verringert die Folgen des Schreibens in den Container; der Anwendung bleibt nur `/tmp` in einem
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

Belege beide Ergebnisse durch einen Live-Aufruf und nicht nur durch das Lesen von YAML: Der Container läuft mit
`runAsUser: 1000` und read-only root, daher muss ein Schreiben außerhalb von `/tmp` mit einem
Dateisystemfehler enden, während ein Schreiben in das gemountete `emptyDir` gelingen muss:

```bash
kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'touch /root-write-test.txt'
# touch: /root-write-test.txt: Read-only file system

kubectl exec -n psa-restricted-107 restricted-app -- sh -c 'echo probe > /tmp/test.txt && cat /tmp/test.txt'
# probe
```

Wenn `restricted-app` bereits ohne read-only filesystem erstellt wurde, kann dieses Feld des Pods nicht geändert werden;
lösche ihn und erstelle ihn erneut (wenn du das erst nach Aufgabe 6 tust, füge in die `spec`
das Feld `automountServiceAccountToken: false` ein - sonst lehnt die policy aus Aufgabe 6 den Pod ab):

```bash
kubectl delete pod restricted-app -n psa-restricted-107
kubectl apply -f restricted-app.yaml
```

## 3. Audit und warn für baseline

Diese Modi verbieten die Anfrage nicht. `warn` gibt dem Client eine Warnung zurück, und `audit`
fügt dem audit event des API server die annotation
`pod-security.kubernetes.io/audit-violations` hinzu. Setze für eine schrittweise Einführung kein
`enforce` im Beobachtungs-Namespace:

```bash
kubectl label namespace psa-observe-107 \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/audit-version=v1.36 \
  pod-security.kubernetes.io/warn=baseline \
  pod-security.kubernetes.io/warn-version=v1.36
```

> **Versionsvorbehalt.** `v1.36` ist für Kubernetes 1.36.0 in dieser Lerninfrastruktur festgelegt.
> Stand 2026-09-06 orientiert sich die offizielle CKS-Prüfung an `v1.35`; das ist ein
> forward-looking Beispiel, und bei der Vorbereitung auf die Prüfung verwende `*-version=v1.35`.

> **Grenze des audit-Nachweises.** Das Lab konfiguriert keinen audit-log sink, daher
> lässt sich `pod-security.kubernetes.io/audit-violations` nicht mit dem Befehl `kubectl` abrufen.
> Als tatsächlich prüfbares Ergebnis dienen unten die PSA-Warnung und die erfolgreiche admission; die audit
> annotation ist erklärt, aber in dieser Infrastruktur kein prüfbares Artefakt.

## 4. Sicherstellen, dass warn/audit den Pod nicht blockieren

Dieser Pod verletzt baseline wegen `hostNetwork`, wird aber akzeptiert, weil der Namespace
kein `enforce` hat. `kubectl apply` gibt die PSA-Warnung aus; ignoriere sie bei der Migration
von production workloads nicht.

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

## 6. Native ValidatingAdmissionPolicy ohne Kyverno/Gatekeeper

PSA `restricted` verlangt bereits `allowPrivilegeEscalation: false` und `capabilities.drop`
mit `ALL` - Aufgabe 2 zeigt genau das, und das ist ein eingebauter Teil des Pod Security
Standards und keine Lücke. Aber PSS `restricted` **prüft nicht** `automountServiceAccountToken`:
Ein Pod kann still einen gemounteten ServiceAccount token erhalten und PSA vollständig bestehen. Für
dieses separate, tatsächlich nicht abgedeckte control ist genau eine custom `ValidatingAdmissionPolicy` angebracht.

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

Belege alle drei Zustände per server-side dry-run, ohne einen dauerhaften Pod zu speichern. Ein Pod ohne
das Feld muss ein DENY von genau dem Paar policy + binding erhalten, `false` muss durchgehen, und
`true` muss ein DENY von demselben Paar erhalten. Der erste Pod
entspricht vollständig PSA `restricted` (non-root, seccomp, `allowPrivilegeEscalation:
false`, `capabilities.drop: ["ALL"]`) - PSA selbst würde ihn akzeptieren, daher muss die Ablehnung
genau von der neuen policy kommen und nicht von `violates PodSecurity`:

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

Derselbe Pod mit hinzugefügtem `automountServiceAccountToken: false` muss durchgehen:

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

Der explizite Wert `true` muss ebenfalls von derselben policy und demselben binding abgelehnt werden:

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

`Binding.matchResources.namespaceSelector` begrenzt die policy nur auf `psa-restricted-107`:
Pods in anderen Namespaces (zum Beispiel `psa-observe-107`) werden von dieser Regel nicht geprüft und
erhalten kein überflüssiges Deny.

## 7. Controller-driven admission denial

Zuerst ein einfaches, nicht hardened Deployment - PSA ist noch nicht enforce, alles geht durch:

```bash
kubectl -n psa-controller-107 create deployment controller-app --image=busybox:1.36 -- sh -c "sleep 3600"
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

Wir aktivieren enforce - der vorhandene Pod wird nicht angetastet:

```bash
kubectl label namespace psa-controller-107 \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=v1.36
kubectl -n psa-controller-107 get pod
# controller-app-xxxx ist weiterhin Running - PSA wirkt nicht auf bereits vorhandene Objekte
```

Wir löschen den Pod - das ReplicaSet versucht, einen Ersatz zu erstellen, und erhält eine Ablehnung:

```bash
kubectl -n psa-controller-107 delete pod -l app=controller-app
kubectl -n psa-controller-107 get events --sort-by=.lastTimestamp | tail -5
# ... FailedCreate ... violates PodSecurity "restricted:v1.36": ...
kubectl -n psa-controller-107 get deploy controller-app
# controller-app   0/1     1            0           ...   <- READY 0/1, AVAILABLE 0
```

Wir reparieren das template - wir fügen dieselben hardening-Felder wie in Aufgabe 2 hinzu:

```bash
kubectl -n psa-controller-107 edit deployment controller-app
```

Ersetze in `spec.template.spec` die Zeile `securityContext: {}` durch den Block unten und füge im Container `busybox`
(der Name des Containers ist `busybox`, erstellt von `kubectl create deployment`) seinen eigenen `securityContext` hinzu:

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

Speichere und warte auf den rollout:

```bash
kubectl -n psa-controller-107 rollout status deployment/controller-app
```

```
deployment "controller-app" successfully rolled out
```

```bash
check_result
```
