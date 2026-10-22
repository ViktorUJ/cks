[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 107 - Pod Security Admission: restricted, audit/warn und read-only root filesystem

## Ziel

In diesem CKS-Lab konfigurierst du das eingebaute **Pod Security Admission (PSA)** über
Labels des Namespace. Für den production Namespace wird `restricted` im Modus
`enforce` aktiviert, die Ablehnung eines unsicheren Pods geprüft und ein hardened Pod ausgerollt, der die Admission-Prüfung besteht.
Für einen separaten Namespace aktivierst du die beobachtenden Modi `audit` und `warn` der Stufe
`baseline`. Abschließend wird das root filesystem des Containers read-only, und das einzige
notwendige Schreiben wird in ein `emptyDir` erlaubt.

Arbeite nur mit den Objekten aus den Aufgaben. Im Cluster wurden vorab die leeren Namespaces
`psa-restricted-107`, `psa-observe-107` und `psa-controller-107` erstellt; PSA-Labels und workloads gibt es darin nicht.

## Prüfe dich vor dem Start

<details>
<summary>1. Wie unterscheidet sich `enforce` von `audit`/`warn` in Pod Security Admission?</summary>

`enforce` blockiert tatsächlich die Erstellung eines Pods, der die gewählte PSS-Stufe verletzt - der admission request endet mit einem Fehler. `audit`/`warn` blockieren die Anfrage NICHT: Der Pod wird trotzdem erstellt, aber `audit` fügt eine annotation in das audit log des kube-apiserver ein, und `warn` zeigt dem Benutzer bei `kubectl apply` eine Textwarnung. Das sind unterschiedliche Verantwortungsebenen: `audit`/`warn` dienen der Beobachtung vor dem Einschalten der echten Blockierung, `enforce` ist der eigentliche Schutz.
</details>

<details>
<summary>2. Warum muss man für einen Namespace das Label `*-version` zusammen mit der PSS-Stufe festlegen?</summary>

Ohne eine feste Version (`enforce-version`) verwendet PSA bei jeder Prüfung die aktuelle Kubernetes-Version - wenn der Cluster aktualisiert wird, kann sich der Regelsatz von `restricted`/`baseline` unbemerkt für dich ändern, und ein Pod, der gestern durchging, kann heute ohne dein Zutun abgelehnt werden. Das Festlegen der Version macht das Verhalten vorhersehbar und reproduzierbar, unabhängig von künftigen Cluster-Updates.
</details>

<details>
<summary>3. Warum dupliziert die `ValidatingAdmissionPolicy` aus Aufgabe 6 PSA nicht, sondern ergänzt es?</summary>

PSS `restricted` definiert einen festen, standardisierten Satz von security-Feldern (non-root, capabilities, seccomp, escalation). `automountServiceAccountToken` gehört NICHT zu diesem Satz - PSA prüft es überhaupt nicht. Das bedeutet, dass ein Pod vollständig mit `restricted` kompatibel sein und trotzdem still einen gemounteten API-token erhalten kann, den er nicht braucht. Die custom `ValidatingAdmissionPolicy` schließt genau diese Lücke, ohne zu versuchen, das zu ersetzen oder zu duplizieren, was PSA bereits tut.
</details>

## Infrastruktur

Die Umgebung wird über Terragrunt in AWS `eu-central-1` ausgerollt:

| Komponente | Zweck |
|---|---|
| `vpc` | VPC `10.10.0.0/16` mit öffentlichen Subnetzen |
| `ssh-keys` | SSH-Schlüssel für den Zugriff auf die Maschinen |
| `k8s-1` | Ein-Node-kubeadm-Cluster Kubernetes `1.36.0`, containerd und **Calico** |
| `worker` | Arbeitsmaschine mit `kubectl`, dem Kontext `cluster1-admin@cluster1` und `check_result` |

Die control-plane akzeptiert gewöhnliche Pods, daher wird kein separater Kubernetes-worker-Node
benötigt. Alle Aufgaben werden auf der Arbeitsmaschine ausgeführt.

## Bereitstellung

```bash
TASK=107 make run_cks_task
```

Verbinde dich per SSH mit der Arbeitsmaschine und prüfe den Zugriff auf den Cluster:

```bash
time_left
kubectl get nodes
check_result
```

## Aufgaben

---
| **1** | **Enforce restricted mit festgelegter Version** |
| :---: | :--- |
| Was wir tun | Setze auf dem Namespace `psa-restricted-107` `pod-security.kubernetes.io/enforce=restricted` und `pod-security.kubernetes.io/enforce-version=v1.36`. Stelle sicher, dass PSA einen unsicheren Pod tatsächlich ablehnt: Ein server-side dry-run eines Pods mit `hostNetwork: true` in diesem Namespace muss mit einem Fehler mit `violates PodSecurity` enden. Ändere nicht die Labels der System-Namespaces. |
| Abnahmekriterien | Beide enforce-Labels haben die exakten Werte; ein unsicherer Pod besteht die admission in `psa-restricted-107` nicht; die System-Namespaces `kube-system`, `kube-public` und `kube-node-lease` erhalten im Rahmen dieses Labs keine `pod-security.kubernetes.io/*`-Labels. |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

`kubectl label namespace psa-restricted-107 pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=v1.36` - beide Labels wirken sofort, PSA erfordert keinen Neustart von irgendetwas. Prüfe dich selbst über `kubectl apply --dry-run=server` mit `hostNetwork: true` - genau `--dry-run=server` (nicht `client`), weil admission controllers, einschließlich PSA, nur server-side arbeiten.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

Zuerst die Baseline - stelle VOR dem Setzen der Labels sicher, dass dasselbe unsichere Manifest
durchgeht (sonst ist unklar, ob das denial von deinem enforce label oder von etwas anderem verursacht wurde):

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

Setze beide Labels und wiederhole dann DASSELBE Manifest - jetzt muss ein admission-Fehler
mit dem Text `violates PodSecurity` auftreten:

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
| **2** | **Hardened Pod, der restricted besteht** |
| :---: | :--- |
| Was wir tun | Erstelle den Pod `restricted-app` in `psa-restricted-107` aus `busybox:1.36`, der nicht als root läuft und nicht sofort beendet wird. Setze pod-level `runAsNonRoot: true`, `runAsUser: 1000` und `seccompProfile: RuntimeDefault`. Verbiete im container securityContext die privilege escalation, entferne die capability `ALL`, lasse `privileged: false` explizit stehen und setze `seccompProfile: RuntimeDefault`. |
| Abnahmekriterien | Der Pod wird von PSA akzeptiert und läuft; er arbeitet als UID 1000/non-root, und kein container/init/ephemeral container überschreibt das pod-level `runAsUser: 1000`; seccomp - `RuntimeDefault`; escalation und privileged sind verboten; capabilities `ALL` sind entfernt. |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Wenn der Pod eine admission rejection erhält - lies die Fehlermeldung aufmerksam, sie nennt gewöhnlich GENAU das fehlende Feld (zum Beispiel „container has no capabilities.drop“). Ein wichtiges Detail zur Semantik von PSS `restricted` in Kubernetes 1.36: Es verlangt ein effektives (nicht unbedingt buchstäblich dupliziertes) zulässiges `seccompProfile` - das pod-level Profil (`spec.securityContext.seccompProfile.type`) kann von Containern geerbt werden, bei denen das eigene Feld nicht gesetzt ist, und umgekehrt genügt das container-level Feld, wenn es explizit bei ALLEN Containern gesetzt ist, auch ohne pod-level Profil. Das heißt, PSS selbst verlangt nicht buchstäblich BEIDE Ebenen gleichzeitig. **In diesem Lab verlangen wir absichtlich, `RuntimeDefault` explizit sowohl am Pod als auch am Container zu setzen** - nicht weil PSS das verlangt, sondern damit du mit beiden Konfigurationsebenen übst. Ebenso ist `runAsUser: 1000` eine explizite hardening-Entscheidung genau dieses Labs: PSS `restricted` verbietet UID `0`, verlangt aber nicht konkret `1000` (jeder von null verschiedene Wert oder das völlige Fehlen des Feldes ist für PSS selbst zulässig).
</details>

---
| **3** | **Beobachtende Modi baseline** |
| :---: | :--- |
| Was wir tun | Aktiviere auf dem Namespace `psa-observe-107` beide PSA-Modi: `pod-security.kubernetes.io/audit=baseline`, `pod-security.kubernetes.io/audit-version=v1.36`, `pod-security.kubernetes.io/warn=baseline`, `pod-security.kubernetes.io/warn-version=v1.36`. Füge kein `enforce` hinzu: Das ist ein Namespace für schrittweise Beobachtung vor der Blockierung. |
| Abnahmekriterien | Vier audit/warn-Labels mit der Stufe `baseline` und der Version `v1.36` sind vorhanden; das enforce-Label fehlt. |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Vier separate Labels - man vergisst leicht eines davon (besonders das `-version` für einen der Modi). Prüfe alle vier auf einmal: `kubectl get namespace psa-observe-107 -o jsonpath='{.metadata.labels}' | jq`.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

Baseline - VOR dem Setzen der Labels muss das verletzende Manifest ohne PSA-Warnung durchgehen
(der Namespace wird noch nicht beobachtet):

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

Setze alle vier Labels und wiederhole dann DASSELBE Manifest - jetzt muss `kubectl apply`
`Warning: ... would violate PodSecurity "baseline:v1.36"` ausgeben, und der Befehl
muss trotzdem erfolgreich enden (exit 0) und nicht mit einem Fehler:

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
| **4** | **Warn/audit blockieren Legacy-workloads nicht** |
| :---: | :--- |
| Was wir tun | Erstelle in `psa-observe-107` den Pod `baseline-audit-sample` aus `busybox:1.36`, der mit `hostNetwork: true` läuft und `sleep 3600` ausführt. Halte bei `kubectl apply` die PSA-Warnung über die Verletzung von baseline fest: Der Pod muss erstellt werden, weil `warn` und `audit` die Anfrage für sich genommen nicht verbieten. |
| Abnahmekriterien | `baseline-audit-sample` existiert, hat `hostNetwork: true` und wurde von der API zugelassen; im Namespace gibt es weiterhin keinen enforce-Modus. |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

Wenn der Pod NICHT erstellt wurde - prüfe, ob du in Aufgabe 3 versehentlich das `enforce` label gesetzt hast statt nur `audit`/`warn`. Die Warnung von PSA erscheint direkt in der Ausgabe von `kubectl apply` (`Warning: would violate PodSecurity "baseline:v1.36"`), du musst sie nicht in einem separaten Log suchen.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

Diese Aufgabe wiederholt faktisch den self-check aus Aufgabe 3, aber mit einem dauerhaften Pod. Stelle nach dem
Erstellen von `baseline-audit-sample` sicher, dass er tatsächlich existiert und
`Running`/`Pending` ist (nicht abgelehnt wurde):

```bash
kubectl get pod baseline-audit-sample -n psa-observe-107 -o jsonpath='{.status.phase}{"\n"}{.spec.hostNetwork}'
```

Vergleiche mit dem Namespace `psa-restricted-107` (Aufgabe 1): Dasselbe unsichere Manifest MUSS dort
abgelehnt werden, hier dagegen wird es angenommen. Der Unterschied liegt genau im `enforce` label, das
bei einem Namespace vorhanden ist und beim anderen fehlt:

```bash
kubectl get namespace psa-restricted-107 psa-observe-107 --show-labels
```
</details>

---
| **5** | **Read-only root filesystem mit beschreibbarem emptyDir** |
| :---: | :--- |
| Was wir tun | Überarbeite `restricted-app`: Aktiviere am Container `readOnlyRootFilesystem: true`. Erstelle ein volume `writable-tmp` vom Typ `emptyDir` (empfohlen `medium: Memory`, damit temporäre Dateien nicht auf die Platte des Nodes gelangen) und mounte es unter `/tmp` ohne `readOnly: true`. Der Container darf nur in dieses temporäre Volume schreiben; verwende kein `hostPath`. Belege beide Ergebnisse durch einen Live-Aufruf im Pod: Der Versuch, in das Root-Dateisystem des Containers zu schreiben (zum Beispiel `touch /root-write-test.txt`), muss mit dem Fehler `Read-only file system` enden, während das Schreiben in `/tmp/test.txt` erfolgreich sein muss. Wenn du unveränderliche Felder des Pods änderst, lösche `restricted-app` und erstelle ihn mit demselben Namen neu. |
| Abnahmekriterien | Der Container hat ein read-only root filesystem; ein `emptyDir` mit dem Namen `writable-tmp` ist unter `/tmp` als beschreibbar gemountet; für regular containers ist das das einzige beschreibbare declarative `volumeMount`, und alle zusätzlichen `volumeMounts` sind read-only; die hardened-Einstellungen aus Aufgabe 2 sind erhalten; der Live-Versuch, in das Root-Dateisystem des Containers zu schreiben, liefert `Read-only file system`, und das Schreiben nach `/tmp/test.txt` endet erfolgreich mit lesbarem Inhalt. |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

`readOnlyRootFilesystem` gehört zu den Feldern, die bei einem bereits vorhandenen Pod nicht geändert werden können (immutable field) - `kubectl apply` mit geändertem securityContext gibt einen Fehler zurück. Lösche den Pod (`kubectl delete pod restricted-app`) und erstelle ihn mit demselben Namen neu, statt zu versuchen, den vorhandenen an Ort und Stelle zu aktualisieren.
</details>

---
| **6** | **Native ValidatingAdmissionPolicy: `automountServiceAccountToken: false` verlangen** |
| :---: | :--- |
| Was wir tun | • PSA `restricted` verlangt bereits `allowPrivilegeEscalation: false`, `capabilities.drop`, das `ALL` enthält, non-root und seccomp - Aufgabe 2 zeigt genau das.<br/>• Aber PSS `restricted` **prüft nicht** `automountServiceAccountToken`: Ein Pod, der die Kubernetes API nicht braucht, kann still einen gemounteten ServiceAccount token erhalten und PSA vollständig bestehen. Das ist ein eigenes, von PSS nicht abgedecktes control, daher ist hier genau eine custom `ValidatingAdmissionPolicy` angebracht und keine Duplizierung des eingebauten PSA.<br/>• Erstelle die `ValidatingAdmissionPolicy` `require-no-automount-token` mit einem CEL-Ausdruck, der `automountServiceAccountToken == false` auf Pod-Ebene verlangt.<br/>• Wende das `ValidatingAdmissionPolicyBinding` `require-no-automount-token-binding` an, begrenzt durch `matchResources.namespaceSelector` auf `psa-restricted-107`, mit `validationActions: [Deny]`.<br/>• Belege alle drei Zustände per server-side dry-run: Ein vollständig PSA-kompatibler Pod (mit allen Feldern aus Aufgabe 2 - non-root, seccomp, drop ALL, escalation false) ohne das Feld muss ein DENY von genau dem Paar policy+binding erhalten; `automountServiceAccountToken: false` muss ALLOW erhalten; `automountServiceAccountToken: true` muss wieder ein DENY von demselben Paar erhalten.<br/>• Nach dem Erstellen der policy müssen neue Pods in `psa-restricted-107` (auch der neu erstellte `restricted-app`) selbst `automountServiceAccountToken: false` enthalten, sonst lehnt die policy sie ab. |
| Abnahmekriterien | • **Objekte:** `ValidatingAdmissionPolicy require-no-automount-token` und ihr `ValidatingAdmissionPolicyBinding` existieren, `validationActions` enthält `Deny`, das Binding matcht nur `psa-restricted-107`. Im Lab existiert genau ein Binding für diese policy - `require-no-automount-token-binding`; zusätzliche Bindings dieser policy für andere Namespaces werden nicht erstellt.<br/>• **Drei Zustände:** Der server-side dry-run eines PSA-kompatiblen Pods ohne `automountServiceAccountToken: false` wird genau vom Paar `ValidatingAdmissionPolicy 'require-no-automount-token'` und `ValidatingAdmissionPolicyBinding 'require-no-automount-token-binding'` abgelehnt (nicht mit der PSA-Meldung `violates PodSecurity` und nicht von einer anderen policy); ein Pod mit `automountServiceAccountToken: false` wird akzeptiert, und ein Pod mit `automountServiceAccountToken: true` wird von genau demselben Paar abgelehnt.<br/>• **Abdeckung aller Pods:** Die policy deckt alle durch ihre `resourceRules` ausgewählten Pods innerhalb von `psa-restricted-107` ab. Füge in der `ValidatingAdmissionPolicy` kein `spec.matchConditions`, `matchConstraints.objectSelector` oder `matchConstraints.namespaceSelector` hinzu und im Binding in `matchResources` kein `objectSelector` - sie verengen die coverage auf einen Teil der Pods, und ein workload könnte anhand eines Labels oder einer Bedingung der Anfrage aus der Prüfung herausfallen.<br/>• **Namespace scope:** wird nur durch `matchResources.namespaceSelector` des Bindings festgelegt, genau an `psa-restricted-107` gebunden; der selector enthält keine Bedingungen zu anderen namespace-label keys und begrenzt den scope von sich aus eindeutig auf diesen Namespace.<br/>• **CEL:** Die validation enthält keine Ausnahmen nach Name/Labels/Annotations des Pods, user/request, `namespaceObject`, `params`, `variables` oder anderen Feldern: Die Entscheidung hängt nur von `object.spec.automountServiceAccountToken` ab (jede korrekte CEL-Form ist zulässig, auch die optional-Syntax `object.spec.?automountServiceAccountToken.orValue(true) == false`). `spec.auditAnnotations` fehlt oder ist leer: Deren separate CEL expressions können über `failurePolicy` die admission beeinflussen, daher wird die admission control nur durch `spec.validations` festgelegt. `variables` und `paramKind` werden nicht verwendet.<br/>• **Resource scope:** `matchConstraints.resourceRules` begrenzen die policy genau auf `core/v1 pods` für die Operationen `CREATE` und `UPDATE`, ohne `resourceNames`; `scope` fehlt, ist `*` oder `Namespaced`, aber nicht `Cluster`; `excludeResourceRules` werden nicht verwendet. Das Binding verengt den resource/operation scope nicht durch eigene `resourceRules`/`excludeResourceRules`.<br/>• Das erlaubt es, den vollständigen boolean contract mit drei Zuständen `missing / false / true` zu belegen und nicht mit einigen ausgewählten workload-Beispielen. |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

Der Test-Pod für diese Aufgabe muss VOLLSTÄNDIG PSA-kompatibel sein (alle Felder aus Aufgabe 2), außer dem fehlenden `automountServiceAccountToken: false` - wenn der Test-Pod gleichzeitig PSS und deine neue policy verletzt, kannst du nicht belegen, dass genau DEINE policy gegriffen hat und nicht das eingebaute PSA. Ein `ValidatingAdmissionPolicyBinding` ohne `matchResources.namespaceSelector` wirkt auf den GESAMTEN Cluster - begrenze den scope unbedingt GENAU auf einen Namespace `psa-restricted-107` (zum Beispiel über `matchLabels: {kubernetes.io/metadata.name: psa-restricted-107}`) und nicht über `matchExpressions` mit mehreren Werten, bei denen `psa-restricted-107` nur einer von mehreren passenden Namespaces ist: Wenn dein selector zufällig auch `psa-observe-107` matcht, beginnt dieselbe Regel dort unerwartet ebenfalls zu wirken.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

Baseline - VOR dem Erstellen von VAP/Binding muss derselbe PSA-kompatible Pod, aber ohne automount opt-out,
durchgehen (PSA selbst lehnt ihn nicht ab, `automountServiceAccountToken` gehört nicht
zu PSS):

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

Erstelle VAP + Binding und wiederhole das Manifest ohne das Feld - jetzt muss die Anfrage ein
DENY genau von der `ValidatingAdmissionPolicy 'require-no-automount-token'` über das Binding
`require-no-automount-token-binding` erhalten, NICHT von PSA. Prüfe dann beide expliziten Werte:
`false` muss durchgehen, und `true` muss ein DENY von genau demselben Paar erhalten.

```bash
kubectl apply -f require-no-automount-token.yaml   # deine VAP + Binding

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
# erwartet: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Setze mit demselben PSA-kompatiblen Manifest `automountServiceAccountToken: false` - die Anfrage
muss durchgehen:

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
# erwartet: pod/self-check-automount-false created (oder server-side dry-run success)
```

Setze jetzt `automountServiceAccountToken: true` - die Anfrage muss wieder von
genau derselben policy und demselben binding abgelehnt werden:

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
# erwartet: ValidatingAdmissionPolicy 'require-no-automount-token' with binding
# 'require-no-automount-token-binding' denied request: ...
```

Prüfe schließlich - und das ist das Wichtigste - die GRENZE des scope und nicht nur die Tatsache des denial: Dasselbe
Manifest (ohne automount opt-out), aber im Namespace `psa-observe-107`, muss DURCHGEHEN - wenn
es ebenfalls abgelehnt wird, matcht dein `namespaceSelector` mehr als einen Namespace:

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
# erwartet: 0 (nicht denied) - sonst ist der scope des Bindings zu breit
```
</details>

---

| **7** | **Controller-driven admission denial: Diagnose über ReplicaSet events** |
| :---: | :--- |
| Was wir tun | Erstelle im leeren Namespace `psa-controller-107` ein Deployment `controller-app` (Label `app=controller-app`, replicas=1) mit einem einfachen Pod template ohne hardening (zum Beispiel `busybox:1.36`, `sleep 3600`, ohne `securityContext`) - es muss erfolgreich starten, PSA stört vorerst nicht. Aktiviere dann auf diesem Namespace `pod-security.kubernetes.io/enforce=restricted` und `enforce-version=v1.36` (der bereits vorhandene Pod läuft weiter - PSA fasst bereits erstellte Objekte nicht an). Lösche den aktuellen Pod: Das ReplicaSet versucht, einen Ersatz zu erstellen, und jetzt lehnt ihn die admission ab. Prüfe die Ursache über `kubectl -n psa-controller-107 describe rs` und `kubectl -n psa-controller-107 get events` - dort steht `FailedCreate` mit dem Text `violates PodSecurity "restricted:v1.36"`. Korrigiere das Pod template des Deployments (füge dieselben hardening-Felder wie in Aufgabe 2 hinzu: non-root, `seccompProfile: RuntimeDefault`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false`) und warte, bis das ReplicaSet erfolgreich einen neuen Pod erstellt, der die admission besteht. |
| Abnahmekriterien | Im Namespace gilt enforce `restricted:v1.36`; das Pod template im Deployment entspricht vollständig PSS `restricted`; nach dem Löschen des aktuellen Pods erstellt das ReplicaSet tatsächlich einen neuen Ready Pod unter dem aktuellen enforce-Modus (nicht einfach „das Objekt existiert“ - es wird durch tatsächliches Löschen und erneutes Erstellen geprüft). |

<details>
<summary>💡 Hinweis zu Aufgabe 7</summary>

Die Reihenfolge ist wichtig: zuerst das Deployment ohne hardening (geht durch, PSA ist noch nicht enforce), dann
das Label enforce=restricted auf den Namespace (der vorhandene Pod bleibt unberührt), dann `kubectl
delete pod -l app=controller-app` - genau hier stößt das ReplicaSet auf das admission deny.
Wenn du den Pod nicht manuell löschst, siehst du die Ablehnung überhaupt nicht, bevor auf natürliche Weise
irgendein reschedule geschieht. Korrigiert werden muss genau das `spec.template` im Deployment (`kubectl
edit deployment controller-app` oder `kubectl apply` mit korrigiertem Manifest) und nicht das
namespace label - den enforce-Modus zurückzunehmen ist nicht die Lösung dieser Aufgabe.
</details>

---

## Prüfung

Führe auf der Arbeitsmaschine aus:

```bash
check_result
```

Die Prüfung enthält Init und sieben unabhängige Aufgaben. Sie führt zusätzlich einen
server-side dry-run eines unsicheren Pods aus, daher ist das Fehlen eines dauerhaften „schlechten“ Pods im
restricted Namespace ein erwartetes und korrektes Ergebnis. Bei Aufgabe 7 löscht der Checker selbst
den aktuellen Pod `controller-app` und prüft, dass das ReplicaSet tatsächlich einen Ready Pod neu erstellt -
den Text der events akzeptiert er nicht als Beleg.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD)

## Löschen

```bash
TASK=107 make delete_cks_task
```

## Hinweis zur PSA-Version und Beobachtbarkeit von audit

Das Lab legt die PSA-Labels absichtlich auf `v1.36` fest, da der Lern-Cluster selbst auf
Kubernetes 1.36.0 läuft. Stand 2026-09-06 orientiert sich der offizielle CKS blueprint an Kubernetes
`v1.35`; daher ist das eine **forward-looking** Lernkonfiguration und keine Aussage über die Version der Prüfung.
Ersetze zur Vorbereitung auf die aktuelle Prüfung die Suffixe `*-version` durch `v1.35` und
gleiche das Verhalten mit der Dokumentation dieser Version ab.

Der Modus `audit` fügt dem **audit event des kube-apiserver** die annotation
`pod-security.kubernetes.io/audit-violations` für den verletzenden Pod hinzu. Die Lerninfrastruktur
konfiguriert keinen audit-log sink und stellt keinen bereit, daher lässt sich diese annotation hier nicht über `kubectl` lesen.
Der beobachtbare Beleg in Aufgabe 4 ist die PSA-Warnung
(`Warning: ... would violate PodSecurity "baseline"`) bei der server-side admission und die erfolgreiche
Erstellung des Pods ohne `enforce`; der audit mode ist erklärt, aber seine log annotation wird von diesem Lab nicht
geprüft.
