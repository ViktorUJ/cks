[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 108 - Admission policies mit Kyverno

## Ziel

In diesem CKS-Lab installierst du Kyverno und schützt den Namespace `policy-108` mit
policy-as-code-Regeln. Die Praxis umfasst validating admission: Verbot des Tags `latest`, obligatorisches
`runAsNonRoot`, Allowlist für Registries; in der letzten, optionalen Phase - mutation des Pods bei
admission. Aufgabe 6 vergleicht diesen Ansatz mit einem anderen Mechanismus - dem eingebauten
`ImagePolicyWebhook`, bei dem die Entscheidung über das Image ein externes HTTP(S)-Backend über die API
`ImageReview` trifft und nicht ein CEL-Ausdruck innerhalb des Clusters. Die abschließende Aufgabe 7 ist eine dritte, separate
admission engine: **Gatekeeper (OPA/Rego)**, bei der du eine bereits ausgerollte, aber unvollständige
policy reparierst, statt CEL innerhalb von Kyverno zu schreiben. Arbeite nur mit den in den Aufgaben genannten
Objekten und Namen.

## Prüfe dich vor dem Start

<details>
<summary>1. Warum deckt das Verbot nur des expliziten Tags `:latest` nicht das gesamte Risiko von mutable-tag ab?</summary>

Wenn ein Image überhaupt ohne Tag angegeben wird (zum Beispiel `nginx`), löst Docker/OCI es standardmäßig als `nginx:latest` auf - implicit latest. Eine policy, die nur den buchstäblichen Treffer des Strings `:latest` prüft, lässt ein solches Image durch, obwohl es semantisch dasselbe ist wie ein explizites `:latest`. Eine korrekte policy muss sowohl explizites als auch implicit latest ablehnen - oder einen expliziten versionierten Tag/digest verlangen.
</details>

<details>
<summary>2. Warum muss eine validating policy `ephemeralContainers` getrennt von `containers`/`initContainers` prüfen?</summary>

`kubectl debug` fügt einen ephemeral container einem BEREITS vorhandenen Pod über eine separate subresource API (`pods/ephemeralcontainers`) hinzu und nicht über ein gewöhnliches CREATE/UPDATE des Pods. Wenn die policy nur die Ressource `pods` matcht, ohne diese subresource explizit einzuschließen, kann der Versuch, einen ungeprüften/untrusted ephemeral container hinzuzufügen, an allen validating policies vorbeigehen, die für gewöhnliche containers geschrieben wurden.
</details>

<details>
<summary>3. Worin besteht der grundsätzliche Unterschied zwischen `ValidatingPolicy` und `MutatingPolicy` in Kyverno?</summary>

`ValidatingPolicy` prüft die Anfrage nur und erlaubt oder lehnt sie ab (Allow/Deny) - das Objekt wird nicht verändert. `MutatingPolicy` VERÄNDERT das Objekt vor dem Speichern (fügt Felder hinzu/ändert sie, zum Beispiel ein Label) - die Anfrage geht trotzdem durch, aber mit verändertem Inhalt. Aufgabe 5 verwendet mutation gerade deshalb, weil das Ziel ist, ein Label automatisch hinzuzufügen und nicht den Pod abzulehnen.
</details>

## Infrastruktur

Die Umgebung wird von Terragrunt in AWS `eu-central-1` ausgerollt:

| Komponente | Zweck |
|---|---|
| `vpc` | VPC `10.10.0.0/16` mit öffentlichen Subnetzen |
| `ssh-keys` | Schlüssel für den Zugriff auf die Nodes |
| `k8s-1` | Ein-Node-kubeadm-Cluster Kubernetes `1.36.0`, containerd und **Calico** |
| `worker` | Arbeitsmaschine mit `kubectl`, Helm und `/usr/local/bin/install-kyverno` |

Die control-plane erlaubt gewöhnliche Pods, daher wird kein separater Kubernetes-worker erstellt.
Kyverno ist im Anfangszustand absichtlich **nicht installiert**: Das ist Teil von Aufgabe 1. Auf der
Arbeitsmaschine ist ein festgelegter installer vorbereitet, bei dem du den chart nicht von Hand heraussuchen musst.
Das Lab legt Kyverno `1.19` fest (Helm chart `3.9.0`) und verwendet die stabilen CEL-basierten APIs
`policies.kyverno.io/v1`. Die legacy `Policy`/`ClusterPolicy` in `kyverno.io/v1` sind ab dieser Version
deprecated und werden nur als migration material betrachtet.

Im Unterschied zu Kyverno ist **Gatekeeper (OPA) für Aufgabe 7 bereits** vom bootstrap des Clusters **installiert**,
zusammen mit einem anfänglichen (absichtlich unvollständigen) `ConstraintTemplate` und `Constraint`.
Das ist Absicht: Aufgabe 7 prüft die Fähigkeit, Rego in einem bereits
vorhandenen `ConstraintTemplate` zu finden und zu ergänzen, und nicht, eine admission engine von Grund auf zu installieren - dieser Teil
wird bereits von Aufgabe 1 für Kyverno trainiert. Aufgabe 7 arbeitet in einem separaten Namespace
`gatekeeper-108`, isoliert von den Kyverno-Aufgaben 1-5 (`policy-108`), damit ein Pod nicht
gleichzeitig von zwei verschiedenen admission engines abgelehnt werden kann.

## Bereitstellung

```bash
TASK=108 make run_cks_task
```

Verbinde dich per SSH mit der Arbeitsmaschine. Der Kontext `cluster1-admin@cluster1` ist bereits eingerichtet.

```bash
time_left
check_result
```

## Aufgaben

---
| **1** | **Kyverno installieren** |
| :---: | :--- |
| Was wir tun | • Installiere Kyverno im Namespace `kyverno`.<br/>• Verwende den auf dem worker vorbereiteten Befehl `/usr/local/bin/install-kyverno`; er wendet den festgelegten Helm chart an.<br/>• Warte auf die Verfügbarkeit des admission controllers. |
| Abnahmekriterien | • Im Cluster gibt es die CRD `validatingpolicies.policies.kyverno.io`<br/>• Die Version von Kyverno ist `1.19.x`<br/>• Mindestens ein Deployment des Namespace `kyverno` hat eine verfügbare Replica |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

`/usr/local/bin/install-kyverno` ist bereits auf die festgelegte Version eingestellt - versuche nicht, Kyverno von Hand mit einem anderen chart per `helm install` zu installieren, das kann zu einer inkompatiblen Version der CRD führen. Warte nach der Installation: Der Pod des admission controllers muss `Available` werden, das geschieht nicht augenblicklich.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

```bash
kubectl get crd validatingpolicies.policies.kyverno.io
kubectl get crd mutatingpolicies.policies.kyverno.io
kubectl get deployment -n kyverno -o wide
kubectl get deployment -n kyverno -o json | \
  jq -r '.items[].spec.template.spec.containers[].image' | grep kyverno
```

Der erste Befehl muss die CRD selbst zurückgeben (nicht den Fehler `NotFound`); die Version des Images muss
`v1.19.` enthalten; mindestens ein Deployment muss `AVAILABLE` größer als `0` haben.
</details>

---
| **2** | **Images mit dem Tag `latest` verbieten** |
| :---: | :--- |
| Was wir tun | • Erstelle die CEL-basierte `ValidatingPolicy` `deny-latest-tag` (`policies.kyverno.io/v1`) mit `validationActions: [Deny]`.<br/>• Sie muss auf Pods und die subresource `pods/ephemeralcontainers` des Namespace `policy-108` angewendet werden.<br/>• Sie muss jedes Image in `containers`, `initContainers` oder `ephemeralContainers` ablehnen, das ein explizites `:latest` ODER implicit latest ist (ein Image überhaupt ohne Tag und ohne digest). |
| Abnahmekriterien | • Die policy existiert und arbeitet im Modus Deny<br/>• Admission lehnt sowohl explizites `:latest` als auch implicit latest (untagged) in jeder der drei Listen von Containern ab, einschließlich eines Images mit Registry-Port ohne Tag (`registry.example:5000/app`), und akzeptiert versionierte trusted images und digest-pinned images in jeder Liste<br/>• Beim UPDATE eines vorhandenen Pods wird die Änderung von `spec.containers[*].image` oder `spec.initContainers[*].image` auf `:latest` ebenfalls von dieser policy abgelehnt (gewöhnliche Pod-image-Felder erlauben in-place UPDATE) |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

`matchConstraints.resourceRules` muss sowohl `pods` als auch die subresource
`pods/ephemeralcontainers` separat abdecken - sonst geht `kubectl debug` an der policy vorbei. Zur
CEL-Logik selbst: Zerlege den Image-String in `registry/path` und `tag` am letzten `:`
NACH dem letzten `/` (das Vorhandensein von `:` vor dem letzten `/` kann Teil des Ports der Registry sein und nicht
des Tags); wenn nach der Zerlegung überhaupt kein Tag vorhanden ist - ist das implicit latest; wenn ein Tag vorhanden ist, aber
gleich `latest` - ist das ebenfalls ein verbotener Fall; ein digest (`@sha256:...`) ist ein eigener, immer
erlaubter Fall, der überhaupt nicht unter den Tag fällt.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

Bevor du die policy anwendest, vergewissere dich, dass der verletzende Pod überhaupt admission besteht
(Baseline) - sonst ist unklar, ob das denial von deiner policy oder von etwas anderem verursacht wurde:

```bash
# baseline: vor dem Anwenden der policy - muss durchgehen (exit 0)
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

Wende die policy an und wiederhole dann DASSELBE Manifest - jetzt muss es mit einem admission-Fehler enden
(exit nicht 0), und die Meldung muss auf deine policy verweisen:

```bash
kubectl apply -f deny-latest-tag.yaml   # deine policy-Datei
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

Wiederhole denselben Zyklus baseline→apply→probe→compare für: ein Image überhaupt ohne Tag
(`registry.k8s.io/pause`), `registry.example:5000/app` (der Doppelpunkt vor dem letzten `/` ist der Port der Registry und kein Tag), `:latest` in `initContainers`, und `:latest`/untagged über
`kubectl debug --image=...` auf einem bereits laufenden erlaubten Pod (`pods/ephemeralcontainers`
subresource). Prüfe schließlich die positive control - ein versionierter Tag muss auch
nach dem Anwenden der policy durchgehen und nicht nur davor.
</details>

---
| **3** | **Ausführung als Nicht-root verlangen** |
| :---: | :--- |
| Was wir tun | • Erstelle die CEL-basierte `ValidatingPolicy` `require-run-as-non-root` im Modus Deny.<br/>• Für jeden Pod in `policy-108` muss das Feld `spec.securityContext.runAsNonRoot` explizit gleich `true` sein.<br/>• Auf Pod-Ebene und bei allen Containern sind `runAsUser: 0` und container-level `runAsNonRoot: false` verboten: Einstellungen des Containers können den Pod-level securityContext überschreiben. |
| Abnahmekriterien | • Die policy existiert und ist Deny<br/>• Ein Pod mit `runAsNonRoot: false` oder ohne dieses Feld, Pod-level `runAsUser: 0` sowie ein Container mit `runAsNonRoot: false` / `runAsUser: 0` in `containers`, `initContainers`, `ephemeralContainers` werden genau von dieser policy abgelehnt<br/>• Ein sicheres explizites container-level `runAsNonRoot: true`, `runAsUser: 1000` wird akzeptiert |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Prüfe genau den EXPLIZITEN Wert `true` und nicht "das Fehlen von `false`" - ein CEL-Ausdruck der Form `object.spec.securityContext.runAsNonRoot == true` besteht nicht, wenn das Feld überhaupt nicht gesetzt ist (`null != true`), und das wird hier GEFORDERT: Die Aufgabe lehnt sowohl ein explizites `false` als auch ein fehlendes Feld ab - beide Fälle müssen denied werden und nicht nur ein explizites `false`.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

```bash
# baseline: vor dem Anwenden der policy müssen beide Varianten durchgehen
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

Wende die policy an und wiederhole beide Manifeste - BEIDE müssen jetzt mit einem admission-Fehler enden.
Prüfe dann die positive control: derselbe Pod, aber mit explizitem
`runAsNonRoot: true`, muss auch nach dem Anwenden der policy durchgehen.
</details>

---
| **4** | **Allowlist der container registry** |
| :---: | :--- |
| Was wir tun | • Erstelle die CEL-basierte `ValidatingPolicy` `allow-approved-registries` im Modus Deny.<br/>• Erlaube für jeden Container (`containers`, `initContainers`, `ephemeralContainers`) nur `registry.k8s.io/*` oder `ghcr.io/cks-lab/*`.<br/>• Verbiete die übrigen image registries. |
| Abnahmekriterien | • Die policy existiert und ist Deny<br/>• Ein untrusted image wird in allen drei Listen abgelehnt<br/>• Beide approved prefixes (`registry.k8s.io/` und `ghcr.io/cks-lab/`) werden in jeder der drei Listen zugelassen<br/>• Ein gewöhnliches Pod UPDATE, das das Image auf eine unapproved registry ändert, wird von der policy selbst abgelehnt<br/>• Geprüft werden außerdem andere unapproved registries und host/path-lookalikes in den init/ephemeral-Listen |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

`startsWith('registry.k8s.io/')` ist die zuverlässigste Prüfung des Präfixes, stelle aber sicher, dass beide erlaubten Registries über OR geprüft werden (eine der beiden passt), und nicht über AND (beide gleichzeitig, was für ein Image unmöglich ist). Prüfe gegen eine ALLOWLIST (ein Image wird NUR zugelassen, wenn es einem der beiden Präfixe entspricht) und nicht gegen eine Denylist speziell für `docker.io` - eine policy, die als "wenn `docker.io` - deny, sonst allow" geschrieben ist, lässt `quay.io`, unqualified images und jede andere Drittanbieter-Registry durch. Stelle außerdem sicher, dass das Präfix mit dem ABSCHLIESSENDEN `/` verglichen wird (`registry.k8s.io/`, nicht nur `registry.k8s.io`), sonst kann ein ähnlich geschriebener Host (`registry.k8s.io.evil.example`) durch einen case-insensitive oder unvollständigen Treffer durchgehen. Vergiss wie in Aufgabe 2 nicht `ephemeralContainers` - das ist dasselbe Muster der Prüfung dreier Listen von Containern.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

```bash
# baseline: vor dem Anwenden der policy - eine untrusted registry muss durchgehen
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

Wende die policy an und wiederhole dasselbe Manifest - jetzt muss es denied werden. Das ist EIN
konkreter untrusted-Wert (`docker.io`) und kein Beleg für eine vollwertige
Allowlist - eine policy, die einfach buchstäblich `docker.io` verbietet, aber zum Beispiel ein unqualified image
(implicit Docker Hub ohne expliziten Host), `quay.io` oder einen ähnlich geschriebenen Host (`registry.k8s.io.evil.example`) durchlässt, besteht ebenfalls diese EINE
Prüfung. Wiederhole denselben baseline→apply→probe→compare mindestens für: ein unqualified
image (`busybox:1.36` überhaupt ohne Host), eine andere explizite Drittanbieter-Registry
(`quay.io/...`), einen ähnlich geschriebenen Host/path (`registry.k8s.io.evil.example/...`,
`ghcr.io/cks-lab.evil/...`), ein untrusted image in `initContainers`, und ein untrusted/trusted
image über `kubectl debug` auf einem bereits laufenden erlaubten Pod. Schließlich die positive control: Ein Pod mit BEIDEN Containern (main + init) aus
`registry.k8s.io`/`ghcr.io/cks-lab` muss durchgehen; prüfe auch `ghcr.io/cks-lab/*`
in init- und ephemeral-Containern und nicht nur in `containers`.
</details>

---
| **5** | **Optional: Label per Kyverno mutieren** |
| :---: | :--- |
| Was wir tun | • Erstelle die CEL-basierte `MutatingPolicy` `add-kyverno-managed-label` (`policies.kyverno.io/v1`), die zu Pods des Namespace `policy-108` das Label `security.cks.io/managed-by: kyverno` hinzufügt, falls es fehlt.<br/>• Verwende mutation und keine validation.<br/>• Mutiere keine Pods in anderen Namespaces. |
| Abnahmekriterien | • Ein server-side dry-run eines Pods mit erlaubter Registry und `runAsNonRoot: true`, der dieses Label noch NICHT hat, erhält es nach der mutation mit dem Wert `kyverno`<br/>• Ein Pod, bei dem das Label BEREITS mit einem anderen Wert gesetzt ist, behält den ursprünglichen Wert<br/>• Ein Pod in `default` bleibt ohne dieses Label<br/>• Diese Phase wird in `check_result` angezeigt, ihr Überspringen ist aber zulässig |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

Diese Phase ist optional - wenn dir die Zeit ausgeht, kannst du sie ohne Risiko für den Rest des Labs überspringen. Der Test-Pod zur Prüfung der mutation muss bereits die policies aus den Aufgaben 2-4 bestehen (trusted registry, non-root) - wenn er selbst von einer der vorherigen policies abgelehnt wird, siehst du das Ergebnis der mutation überhaupt nicht. „Falls es fehlt“ in der Aufgabe ist nicht nur ein Wunsch: Die mutation muss das Vorhandensein des Labels explizit prüfen und das Objekt nicht anfassen, wenn es bereits da ist, sonst ist die Aufgabe nicht erfüllt, auch wenn ein Pod ohne Label den richtigen Wert erhält.
</details>

---
| **6** | **ImagePolicyWebhook: externes Backend statt CEL policy** |
| :---: | :--- |
| Was wir tun | • Auf der Arbeitsmaschine ist bereits `/opt/image-policy-backend/server.py` vorbereitet - ein minimaler HTTPS-Server, der die `ImageReview` API implementiert (lehnt Images mit dem Tag `:latest` oder überhaupt ohne Tag ab).<br/>• Rolle ihn als Deployment im Namespace `image-policy` aus, hinter dem Service `image-policy-backend` auf Port `8443`. Das Backend muss Verbindungen über TLS annehmen (der upstream-Vertrag von `ImagePolicyWebhook` verlangt HTTPS, plain HTTP wird nicht unterstützt).<br/>• Konfiguriere auf der `control-plane` (`ssh`, dann `sudo -i`) eine `AdmissionConfiguration` für das plugin `ImagePolicyWebhook` (`defaultAllow: false`) und eine kubeconfig, die auf dein Backend zeigt.<br/>• **Füge** im static manifest `kube-apiserver.yaml` `ImagePolicyWebhook` zur bereits vorhandenen Liste `--enable-admission-plugins` **hinzu** (ersetze nicht die ganze Liste - sonst riskierst du, bereits aktivierte plugins auszuschalten) und aktiviere `--runtime-config=imagepolicy.k8s.io/v1alpha1=true`.<br/>• Erstelle nach der Wiederherstellung der API einen Pod mit `:latest` - er muss abgelehnt werden; dann einen Pod mit festgelegtem Tag - er muss erstellt werden. |
| Abnahmekriterien | • `image-policy-backend` ist Available<br/>• Kube-apiserver ist healthy mit hinzugefügtem (nicht ersetztem) plugin und `--runtime-config`<br/>• Die kubeconfig des Backends verwendet HTTPS `https://<ClusterIP Service image-policy-backend>:8443/imagepolicy`<br/>• Ein Pod mit `:latest` und implicit latest (auch Registry-Port ohne Tag) wird genau von ImagePolicyWebhook im Namespace `default` abgelehnt - sowohl im gewöhnlichen Pod als auch im init/ephemeral container<br/>• Die Benutzer-Annotation `alpha.image-policy.k8s.io/break-glass: "true"` gibt keine Ausnahme<br/>• Der Namespace `policy-108` ist für Kyverno aus den Aufgaben 2–4 reserviert, damit zwei unabhängige admission-Mechanismen die Ablehnung des jeweils anderen nicht verdecken<br/>• Dazu delegiert das Backend bei `ImageReview.spec.namespace == policy-108` die Entscheidung an Kyverno, während in allen übrigen Namespaces ImagePolicyWebhook weiterarbeitet<br/>• Ein Pod mit festgelegtem Tag wurde erstellt und ist Running<br/>• Der Service verliert während des Backend-Ausfalls tatsächlich die Endpoints, die API lehnt wegen der Nichterreichbarkeit dieses Endpoints ab (`defaultAllow: false`), dann werden Service selector und admission exakt in den ursprünglichen Zustand zurückversetzt |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

`ImagePolicyWebhook` ist ein grundsätzlich anderer Mechanismus als Kyverno aus den Aufgaben 1-5: Die Entscheidung trifft ein externes HTTPS-Backend über die API `ImageReview` und nicht ein CEL-Ausdruck innerhalb des Clusters. Verwende das fertige `/opt/image-policy-backend/server.py` von der Arbeitsmaschine (zum Beispiel als ConfigMap für das Deployment des Backends verpacken; auf die `control-plane` muss nur das CA-Zertifikat für die kubeconfig des webhooks kopiert werden) - die Aufgabe prüft das Verständnis der Anbindung (wiring) des admission plugins, des TLS-Vertrags und der ImageReview API und nicht die Fähigkeit, einen HTTP-Server von Grund auf zu schreiben. Für TLS: Erstelle zuerst den Service (um die `ClusterIP` zu erfahren), dann ein selbstsigniertes Zertifikat mit dieser IP im SAN (`openssl req -x509 -newkey ... -addext "subjectAltName=IP:<ClusterIP>"`), dann das Deployment, das sowohl den Code als auch das Zertifikat mountet. Ersetze das vorhandene `--enable-admission-plugins` nicht vollständig durch einen neuen Wert - hänge `ImagePolicyWebhook` kommagetrennt an die bereits aktivierten plugins an (gewöhnlich ist dort bereits `NodeRestriction`). Vergiss auch nicht `--runtime-config=imagepolicy.k8s.io/v1alpha1=true` - ohne explizites Aktivieren dieser API wird das Backend überhaupt nicht aufgerufen. Der Namespace `image-policy` wird nicht vorab erstellt - erstelle ihn selbst vor Deployment/Service. Wenn du bei der detaillierten Reihenfolge von Ressourcen/Pfaden/Flags hängst - die Referenzabfolge der Aktionen steht in der Lösung.
</details>

---
| **7** | **Gatekeeper ConstraintTemplate: Rego blocklist ergänzen** |
| :---: | :--- |
| Was wir tun | • Im Cluster ist bereits **Gatekeeper** (OPA) installiert sowie ein `ConstraintTemplate` `k8sblockedregistries` und ein `Constraint` `K8sBlockedRegistries/deny-bad-registries`, begrenzt auf einen separaten Namespace `gatekeeper-108` (nicht `policy-108` - das ist ein von den Kyverno-Aufgaben 1-5 getrennter Übungsplatz, damit Kyverno und Gatekeeper nicht denselben Pod gleichzeitig ablehnen).<br/>• Das Rego im `ConstraintTemplate` enthält bereits mehrere blockierte Registries (`untrusted-registry.example`, `docker-fake.test`), enthält aber **absichtlich nicht** `very-bad-registry.test`.<br/>• Finde `ConstraintTemplate.spec.targets[].rego` und ergänze darin die Regel für `very-bad-registry.test` - ausdrücklich im Rego und nicht in den Parametern des `Constraint`.<br/>• `deny-bad-registries` ist bereits vollständig korrekt und verwendet `spec.parameters` überhaupt nicht - es muss nicht angefasst werden. |
| Abnahmekriterien | • `ConstraintTemplate k8sblockedregistries` und das ursprüngliche Constraint `K8sBlockedRegistries/deny-bad-registries` existieren<br/>• Das Rego behält beide ursprünglichen aktiven Regeln (`untrusted-registry.example`, `docker-fake.test`) und enthält die neue aktive Regel für `very-bad-registry.test`<br/>• Ein Pod mit jeder dieser drei Registries in `gatekeeper-108` wird genau vom Constraint `deny-bad-registries` abgelehnt<br/>• Ein Pod mit einem Image aus dem vertrauenswürdigen `registry.k8s.io` geht durch<br/>• Das Constraint bleibt Pod-only, auf `gatekeeper-108` begrenzt, ohne parameters/selectors/exclusions<br/>• Ein zusätzliches Constraint dieses Typs wird nicht erstellt |

<details>
<summary>💡 Hinweis zu Aufgabe 7</summary>

Finde das ConstraintTemplate über `kubectl get constrainttemplate k8sblockedregistries -o yaml`. Das Rego liegt in `spec.targets[].rego` als mehrzeiliger String - genau ihn musst du bearbeiten (`kubectl edit constrainttemplate k8sblockedregistries`, oder `get -o yaml` → Änderung → `apply`). Das vorhandene Rego deklariert die blockierten Registries über einzelne Fakten der Form `blocked_registry("untrusted-registry.example")` - ergänze eine weitere solche Zeile für `very-bad-registry.test`, ohne die bereits vorhandenen zu löschen oder zu ersetzen. Verwechsle das nicht mit `Constraint.spec.parameters` - in dieser Version der policy verwendet das Constraint überhaupt keine parameters, dort gibt es nichts zu bearbeiten.
</details>

<details>
<summary>🔍 Prüfe dich vor `check_result`</summary>

Baseline - VOR der Korrektur: Ein Pod aus `very-bad-registry.test` muss durchgehen (das Rego deckt ihn bisher nicht ab), während das bereits blockierte `untrusted-registry.example` abgelehnt werden muss:

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

Ergänze das Rego und wiederhole DASSELBE Manifest (unter neuem Namen, der alte Pod wurde bereits
über dry-run "erstellt" und wird nicht gespeichert) - jetzt wird ein admission-Fehler von
Gatekeeper erwartet, der ausdrücklich auf `k8sblockedregistries` verweist, für BEIDE Registries:

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

Prüfe die positive control - die vertrauenswürdige Registry muss auch nach der Korrektur durchgehen:

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

## Prüfung

Führe auf der Arbeitsmaschine aus:

```bash
check_result
```

Die Prüfung enthält Init und sieben Tests. Die ersten vier, der sechste und der siebte sind Pflicht. Der fünfte
Test führt die Prüfung der mutation aus, lässt das Lab aber nicht fehlschlagen, wenn die optionale
policy nicht erstellt wurde. Die Aufgaben 2-4 und 7 verwenden `--dry-run=server`, daher werden keine Images
heruntergeladen und es bleiben keine Pods im Namespace; Aufgabe 6 prüft die echte (nicht dry-run)
admission über ImagePolicyWebhook, daher wird der Pod `webhook-pinned-ok` tatsächlich
erstellt.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD)

## Löschen

```bash
TASK=108 make delete_cks_task
```

## Kompatibilität und exakte Semantik des Verbots von Images

Das Lab legt Kubernetes 1.36.0 und Kyverno 1.19 fest, um die neuen
APIs `policies.kyverno.io/v1` kennenzulernen. Das ist eine **forward-looking / unsupported combination**: Kyverno
1.19 wird offiziell mit Kubernetes 1.33–1.35 getestet und nicht mit 1.36. Wähle vor dem Einsatz außerhalb des
Labs eine unterstützte Versionsmatrix und gleiche die release notes ab.

In Aufgabe 2 ist unter dem „Verbot von `latest`“ auch das Verbot des impliziten `latest` zu verstehen: `nginx`
ohne Tag und digest ist ebenso unzulässig wie `nginx:latest`. Erlaubt sind nur Images mit einem expliziten
Tag, der nicht `latest` ist, oder mit einem digest (`@sha256:...`). Die exakte CEL-Logik für dieses
Kriterium gibt die Aufgabe nicht fertig vor - siehe den Hinweis zu Aufgabe 2, wenn du zusätzlichen
Halt brauchst.
