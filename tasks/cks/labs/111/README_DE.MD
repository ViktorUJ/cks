[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 111 - Image-Analyse, statische Korrekturen und supply-chain evidence

## Ziel

In diesem CKS-Lab sammelst du reproduzierbare evidence-artifacts für eine
Anwendung: Berichte von Schwachstellen-Scannern und statischen Analyzern, sichere Korrekturen von
`Dockerfile` und workload-Manifest, zwei SBOMs, die Suche nach Versionen von Abhängigkeiten und die Prüfung der
Signatur eines Images. Das Ergebnis ist nicht einfach eine Terminalausgabe: Jeder Bericht muss
an der angegebenen Stelle gespeichert und auditierbar sein.

Das ist eine CKS-Aufgabe zu security tooling und supply chain und keine CKA-Übung. Die meisten
artifacts werden lokal auf dem worker analysiert; mit dem Cluster arbeiten zusätzlich die Aufgaben 1c, 4, 5b
und 9a-9c (live Deployments, ein hardened Deployment mit Prüfung von Ready/Available und HTTP smoke test, Kyverno policy und Pod).

## Threat model

Das Lab modelliert das Vertrauen in die supply chain über mehrere unabhängige Bedrohungen. Bösartiger
Code oder bekannte Schwächen im Image werden von den Scannern Trivy, kubesec,
kube-linter und Hadolint auf den jeweiligen Ebenen von Image, Dockerfile und Manifesten erkannt.

Secrets und tokens, die versehentlich in einem layer zurückgelassen wurden, erfordern eine separate Prüfung: secret
scanning (zum Beispiel Trivy secret scanning) und Inspektion der history des Images (`docker history`,
Extraktion der Schichten). SBOM löst eine andere Aufgabe - die Inventarisierung von Komponenten und Versionen
der Pakete; es hilft bei der supply-chain investigation (zum Beispiel eine verwundbare Bibliothek zu finden),
ist aber kein zuverlässiger Mechanismus zum Auffinden von Secrets in der Historie der Schichten und ersetzt nicht das secret
scanning. Selbst wenn die Arbeitskonfiguration das Secret bereits nicht mehr enthält, kann es
in der Historie der Schichten zugänglich bleiben.

Die Bedrohung durch mutable-tag tampering besteht darin, dass nach dem Deployment bei einer unveränderten Referenz mit
Tag ein anderes, bösartiges Image untergeschoben werden kann. Genau deshalb ist digest pinning in den
Aufgaben 3–5 wichtig: Es legt den konkreten Inhalt des Images fest und nicht nur seinen Namen und Tag.

Die Signaturprüfung in Aufgabe 7 belegt, dass ein konkreter digest von einem vertrauenswürdigen
key/identity signiert ist (signature integrity), während der Trivy scan in Aufgabe 1 lediglich zeigt, dass bei der aktuellen vulnerability DB
keine bekannten Schwachstellen gefunden wurden, die in seine detection coverage fallen
(Trivy selbst dokumentiert einen trade-off zugunsten der precision, bei dem false
negatives möglich sind - „0 findings“ ist kein formal proof der Abwesenheit von Schwachstellen). Das sind verschiedene
Achsen des Schutzes: Keine von ihnen ersetzt die andere, da vulnerability != signature. Eine Signatur
ist NICHT dasselbe wie provenance/attestation
(zum Beispiel SLSA-style build metadata darüber, woraus und wie ein artifact gebaut wurde): `cosign
verify` bestätigt die Echtheit der Signatur und nicht die vollständige Build-Historie - für attestation
bietet Sigstore separate Befehle `cosign attest`/`cosign verify-attestation`, die in diesem Lab nicht
verwendet werden.

Ein lokales `cosign verify` (Aufgabe 7) ist für sich genommen kein enforcement: Es belegt die
Signatur einer konkreten image reference zum Zeitpunkt der Prüfung, hindert aber niemanden daran, ein
unsigniertes oder anders signiertes Image mit einem direkten `kubectl apply` zu starten und CI zu umgehen. Erst die
admission-time-Prüfung (Aufgabe 9a-9c) macht die Signatur zur Pflichtbedingung für die Zulassung eines
Pods in den Cluster - das ist der Unterschied zwischen „wir haben die Signatur geprüft“ und „der Cluster startet kein
unsigniertes Image“.

Der Nachweis dieser Eigenschaft erfordert Sorgfalt: Ein erneutes `kubectl apply` eines bereits
vorhandenen Deployments erstellt keinen neuen Pod, wenn sich das template nicht geändert hat, daher kann
`Running` „ein alter Pod, erstellt vor der policy“ bedeuten und nicht „die policy hat genau
dieses Image zugelassen“ (Aufgabe 9b prüft `creationTimestamp` explizit). Ebenso belegt ein unsigned
DENY die Eigenschaft nur dann, wenn der geprüfte digest tatsächlich existiert und pullable ist, und zwar im
selben repository wie das signierte Image (Aufgabe 9c) - sonst kann admission wegen eines in der
Registry fehlenden manifests ablehnen und nicht wegen des Fehlens einer Signatur.

## Prüfe dich vor dem Start

<details>
<summary>1. Warum ist SBOM kein zuverlässiger Mechanismus zum Auffinden von Secrets, die in einem image layer zurückgelassen wurden?</summary>

SBOM löst die Aufgabe der Inventarisierung von KOMPONENTEN und Versionen von Paketen (was installiert ist, welche Version) - das ist eine strukturelle Analyse der Metadaten des Paketmanagers und keine Suche nach beliebigen Strings/Secrets im Inhalt der Dateien der Schichten. Ein Secret, das zum Beispiel in einer Umgebungsvariablen ENV oder einer temporären Datei während des Builds zurückgelassen wurde, kann in der Historie der Schichten bleiben, selbst wenn die finale Schicht es nicht enthält - dafür braucht man ein separates Werkzeug (secret scanning, `docker history`, Extraktion der Schichten) und nicht SBOM.
</details>

<details>
<summary>2. Worin besteht der Unterschied zwischen dem, was der Trivy scan (Aufgabe 1) belegt, und dem, was die Cosign-Signatur (Aufgabe 9a-9c) belegt?</summary>

Zum Zeitpunkt der Prüfung hat der Scan bei der aktuellen vulnerability DB und der Erkennungslogik von Trivy KEINE bekannten Schwachstellen ENTDECKT, die in seine detection coverage fallen - das betrifft die Qualität/Sicherheit des Inhalts des Images in dem Maße, in dem Trivy ihn sehen kann. Die Dokumentation von Trivy beschreibt ausdrücklich einen trade-off zugunsten der precision (Minimierung von false positives), bei dem false negatives möglich sind - das heißt, „0 findings“ ist nicht gleichbedeutend mit dem formalen Nachweis der vollständigen Abwesenheit von Schwachstellen. Die Cosign-Signatur belegt SIGNATURE INTEGRITY - dass ein konkreter digest von einem vertrauenswürdigen Schlüssel/identity signiert ist, das heißt, jemand Autorisiertes hat bestätigt, dass dies genau das artifact ist, das ausgerollt werden soll. Das ist NICHT dasselbe wie provenance/attestation (die vollständige Build-Historie - woraus, von wem und wie das artifact gebaut wurde): Für attestation gibt es in Sigstore separate Befehle (`cosign attest`/`cosign verify-attestation`), die in diesem Lab nicht verwendet werden. Ein Image kann vollständig sicher sein (0 CVE) und trotzdem nicht signiert - oder signiert, aber eine unbekannte Schwachstelle enthalten. Das sind zwei unabhängige Achsen des Schutzes.
</details>

<details>
<summary>3. Warum hindert `cosign verify` lokal in CI niemanden daran, ein unsigniertes Image über `kubectl apply` auszurollen?</summary>

`cosign verify`, lokal ausgeführt (zum Beispiel in einer CI pipeline), ist einfach ein Befehl, der die Signatur prüft und dem Aufrufer das Ergebnis zurückgibt. Er ist nicht in den Pfad der admission der Kubernetes API eingebaut - nichts hindert jemanden mit Zugriff auf den Cluster daran, einfach `kubectl apply` mit JEDEM Image auszuführen und CI vollständig zu umgehen. Erst die admission-time-Prüfung (Aufgabe 9a-9c), die als policy in den Cluster selbst eingebaut ist, macht die Signatur zur OBLIGATORISCHEN Zulassungsbedingung - das ist der Unterschied zwischen „wir haben geprüft“ und „der Cluster lässt es physisch nicht durch“.
</details>

## Infrastruktur

Die Umgebung wird von Terragrunt in AWS `eu-central-1` erstellt.

| Komponente | Zweck |
|---|---|
| `vpc` | VPC `10.111.0.0/16` mit öffentlichen Subnetzen |
| `ssh-keys` | Zugriff auf den Node |
| `k8s-1` | Ein-Node-kubeadm Kubernetes `1.36.0`, containerd und **Calico** |
| `worker` | Arbeitsstation für die Analyse, `kubectl`, `check_result` und security tools |

Die Infrastruktur ist CKA-style: Der einzige control-plane-Node ist für workloads erlaubt und
mit `cks.io/lab=111` markiert. Die wichtigsten Befehle und security tools werden auf dem worker gestartet.
Der Kubernetes-Cluster wird als Zielumgebung zur Prüfung des hardened workload und der
admission-time signature policy verwendet: Aufgabe 4 rollt `catalog` aus, und die Aufgaben 9b/9c
führen positive/negative admission probes aus.

Auf dem worker sind vorab genau diese festgelegten Versionen verfügbar:

| Werkzeug | Version | Zweck |
|---|---:|---|
| Trivy | `0.74.0` | CVE und Paketliste des Images |
| kubesec | `2.14.0` | security score von Kubernetes YAML |
| kube-linter | `0.8.3` | policy lint von Kubernetes YAML |
| Hadolint | `2.12.0` | lint von Dockerfile |
| Syft | `1.51.0` | SBOM CycloneDX JSON |
| bom | `0.8.0` | SBOM SPDX JSON (natives Format von `bom`) |
| Cosign | `3.1.3` | signing und verification der Signatur eines OCI-Images |

Helm und `install-kyverno` sind auf dem worker ebenfalls verfügbar, aber Kyverno ist absichtlich **nicht installiert**:
Seine Installation ist Teil von Aufgabe 9, wie in Lab 108. `install-kyverno` legt Kyverno
`1.19`/chart `3.9.0` fest; die offizielle support matrix von upstream für diese Version ist Kubernetes
`1.33-1.35`, während dieser Cluster auf `1.36` läuft. Das ist eine bewusste lab-specific Ausnahme außerhalb des
getesteten Bereichs (analog zum Präzedenzfall in Lab 108) und keine garantierte
offizielle Unterstützung - hebe diese Ausnahme beim Update von Kyverno auf.

## Voraussetzungen und Einschränkungen

**podman und registry sind in der Lab-Umgebung bereits eingerichtet.** Verwende zum Bauen und Veröffentlichen von Images `podman`
(ein Werkzeug aus der Liste der in der CKS-Prüfung erlaubten Werkzeuge; rootless, als Benutzer `ubuntu`). Die Aufgaben 3 und 9c erfordern, ein Image zu bauen und in einer Registry zu **veröffentlichen**, die sowohl vom worker als auch aus dem Cluster erreichbar ist (die immutable-Referenz
`repo@sha256:...` stammt aus der Registry, eine lokale image ID eignet sich nicht). Eine solche Registry -
`registry:2` auf der control-plane - wurde vom bootstrap hochgefahren:

- Adresse: `<IP der control-plane>:5000`, sie steht in `/etc/cks111/registry` auf dem worker;
- Protokoll - gewöhnliches HTTP innerhalb der VPC: podman auf dem worker und containerd auf dem Node sind darauf als
  insecure registry eingestellt (das Flag `--tls-verify=false` wird nicht gebraucht), und in der `ImageValidatingPolicy` für Kyverno ist
  `credentials.allowInsecureRegistry: true` nötig;
- die Daten werden auf einem lokalen PV des Nodes gespeichert (`/var/lib/cks111-registry`), daher überstehen sie
  einen Neustart des Pods der Registry;
- den digest des veröffentlichten Images erhältst du aus `podman push --digestfile`, und das Vorhandensein des Manifests
  prüfst du mit einer Anfrage an `/v2/` (für diese Registry sind HTTPS-only-Werkzeuge wie `docker buildx imagetools` nicht geeignet);
- die detaillierte Abfolge der Befehle steht im Schritt „0. Vorbereitung“ der [Lösung](worker/files/solutions/1_DE.MD).

**Limit von Docker Hub.** Anonyme pulls von einer IP haben ein Limit (etwa 100 Anfragen pro 6 Stunden).
Damit `check_result` nicht daran stößt, lädt der bootstrap die Images des Labs einmalig in einen lokalen Cache
(`nginx:1.27.3-alpine` und Kandidaten für die Aufgaben 1b/1c), und Trivy und Syft nehmen bei wiederholten Scans das
Image aus diesem Cache über dieselbe Referenz `name@sha256:...`, ohne Docker Hub zu kontaktieren. `bom` kann
Images nur aus der Registry lesen, daher macht er pro Start weiterhin einige Anfragen.
Wenn Docker Hub trotzdem `TOOMANYREQUESTS` zurückgibt, warte (das Limit-Fenster ist gleitend) oder führe
`podman login docker.io` mit deinem eigenen Konto aus.

**Cosign und Passwort des Schlüssels.** `cosign generate-key-pair` und `cosign sign --key` fragen nach dem Passwort des
Schlüssels; für ein Übungs-Schlüsselpaar kannst du es leer lassen (`export COSIGN_PASSWORD=""`), damit die Befehle
nicht auf Eingabe warten.

**`trivy sbom` und SBOM ohne OS (Aufgabe 8).** Das SPDX von `bom` enthält für ein multi-arch Image keine
Angaben zum OS: Trivy schreibt `Detected OS family="none"` und findet keine Schwachstellen (`Results` ist leer).
Daher wird in Aufgabe 8 das CycloneDX aus Aufgabe 7 gescannt - darin gibt es die Komponente `operating-system`,
und `trivy sbom` liefert ein nicht leeres `Results`.

## Bereitstellung

```bash
TASK=111 make run_cks_task
```

Verbinde dich mit dem worker und wähle den Kontext:

```bash
kubectl config use-context cluster1-admin@cluster1
cd /home/ubuntu/cks-111
check_result
```

Das ursprüngliche `Dockerfile` und `deployment.yaml` sind absichtlich unsicher. Erstelle Arbeits-artifacts
nur in `/var/work/tests/artifacts/<Nummer>/`.

## Aufgaben

`nginx:1.27.3-alpine` ist ein mutable tag und keine festgelegte Referenz. Hole zuerst den kanonischen registry manifest digest aus `Metadata.RepoDigests[0]` des Trivy JSON und verwende die immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` (im Folgenden `$IMAGE`). Für dein eigenes hardened image baue und veröffentliche das Image zuerst in einer für den Cluster erreichbaren Registry und verwende dann dessen manifest digest; eine lokale image ID und die layer DiffID sind kein registry manifest digest.

---
| **1** | **Trivy: Bericht über Schwachstellen des Images** |
| :---: | :--- |
| Was wir tun | • Scanne das immutable `$IMAGE` mit Trivy, einschließlich OS und library vulnerabilities.<br/>• Speichere das strukturierte JSON in `/var/work/tests/artifacts/1/trivy-report.json`. |
| Abnahmekriterien | • **Datei:** nicht leer, das JSON wird von `jq` geparst, enthält `Results` und die immutable reference des analysierten Images.<br/>• **Frische Prüfung:** Der Checker wiederholt `trivy image` für dasselbe Image selbstständig und verlangt, dass dieser frische Scan erfolgreich ist und in `ArtifactName` übereinstimmt.<br/>• Ein von Hand geschriebenes, aber syntaktisch gültiges JSON besteht nicht. |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

`$IMAGE` wird in zwei Schritten gebildet: Scanne zuerst `nginx:1.27.3-alpine` (gewöhnlicher Tag) und hole `Metadata.RepoDigests[0]` aus DIESEM ersten JSON-Bericht, baue dann den Befehl mit `nginx:1.27.3-alpine@sha256:<digest>` neu auf und scanne bereits die immutable-Referenz - genau dieser zweite Bericht muss als finaler gespeichert werden. Verwende `ImageID`/`DiffID` aus der Ausgabe von Trivy nicht als Ersatz für den registry digest - das sind LOKALE Bezeichner, die nicht mit dem manifest digest in der Registry übereinstimmen.
</details>

---
| **1b** | **Multi-image CVE triage: das Image mit einer konkreten CVE finden** |
| :---: | :--- |
| Was wir tun | • Öffne `~/cks-111/candidates.txt` - dort stehen drei immutable image references (`CANDIDATE_1/2/3`) und die Ziel-CVE `TARGET_CVE`, individuell für deine Instanz des Labs während des bootstrap bestimmt.<br/>• Scanne **alle drei** Images mit Trivy und finde heraus, welches davon tatsächlich `TARGET_CVE` enthält.<br/>• Speichere den JSON-Bericht genau dieses Images in `/var/work/tests/artifacts/1b/target-scan.json`.<br/>• Speichere die Zeile `OFFENDING_IMAGE=<vollständige Referenz dieses Images>` in `/var/work/tests/artifacts/1b/answer.txt`. |
| Abnahmekriterien | • **Antwort:** `answer.txt` nennt genau das `CANDIDATE_N`, dessen echter Trivy-Scan `TARGET_CVE` enthält.<br/>• **Bericht:** `target-scan.json` ist die echte Ausgabe von Trivy für dasselbe Image (der Checker wiederholt den Scan selbst und vergleicht). |

<details>
<summary>💡 Hinweis zu Aufgabe 1b</summary>

`TARGET_CVE` ist bei jeder Instanz des Labs anders - sie wird beim provisioning aus der live Trivy vulnerability DB berechnet und nicht vorab fest eingetragen, daher steht in dieser Datei deine eigene Antwort. Rate nicht anhand des Namens des Tags („das älteste ist wohl verwundbar“) - scanne tatsächlich alle drei und finde den exakten Treffer von `VulnerabilityID` im JSON. Ein Befehl pro Image: `trivy image --format json "$ref" | tee scan.json`, dann `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | index("<TARGET_CVE>")' scan.json` - `null` bedeutet, dass diese konkrete CVE in genau diesem Image fehlt (es können durchaus andere CVE darin sein - das wird nicht geprüft).
</details>

---
| **1c** | **Auswertung der workload images nach Schweregrad CRITICAL** |
| :---: | :--- |
| Was wir tun | • Im Namespace `cks-111` sind bereits 4 Deployments ausgerollt (Label `cks.io/task=1c`), jedes mit einem immutable digest-pinned image.<br/>• Hole die image references aus diesen LIVE Deployments (rate nicht anhand des Tag-Namens), scanne **alle 4** Images mit Trivy mit `--severity CRITICAL` und zähle die Anzahl der eindeutigen CRITICAL `VulnerabilityID` für jedes.<br/>• Bestimme das Deployment mit der größten Anzahl CRITICAL („das verwundbarste“) und die zwei Deployments mit der geringsten Anzahl („die zwei am wenigsten verwundbaren“). Schreibe ihre Namen in `/var/work/tests/artifacts/1c/ranking.txt` als `MOST_VULNERABLE=<deployment-name>`, `LEAST_VULNERABLE_1=<deployment-name>`, `LEAST_VULNERABLE_2=<deployment-name>`.<br/>• Erzeuge für das Image des verwundbarsten Deployments ein CycloneDX SBOM **ausdrücklich mit Trivy** (`trivy image --format cyclonedx`) in `1c/cyclonedx.json`.<br/>• Dann remediate: Lasse `replicas > 0` nur bei den zwei am wenigsten verwundbaren Deployments, skaliere die übrigen zwei (einschließlich des verwundbarsten) auf `replicas: 0`. |
| Abnahmekriterien | • **Ranking:** Der Checker wiederholt den Trivy CRITICAL-Scan aller 4 live images selbst und berechnet das Ranking neu - `ranking.txt` muss mit diesem frischen Scan übereinstimmen und nicht mit einem veralteten/geratenen.<br/>• **SBOM:** `cyclonedx.json` ist ein von Trivy erzeugtes gültiges CycloneDX-Dokument, das sich auf das Image des tatsächlich verwundbarsten Deployments bezieht.<br/>• **Remediation:** genau 2 Deployments (die nach frischem Scan am wenigsten verwundbaren) haben `replicas > 0`, die übrigen 2 - `replicas: 0`. |

<details>
<summary>💡 Hinweis zu Aufgabe 1c</summary>

Hole die image references mit einem Befehl der Form `kubectl -n cks-111 get deployment -l cks.io/task=1c -o jsonpath=...` - versuche nicht, am Namen des Deployments zu erraten, welches Image „neuer“ oder „sicherer“ ist. Befehl zum Zählen: `trivy image --scanners vuln --severity CRITICAL --format json <ref>`, dann `jq '[.Results[]?.Vulnerabilities[]?.VulnerabilityID] | unique | length'`. Für CycloneDX verwende ausdrücklich `trivy image --format cyclonedx --output <file> <ref>` - nicht Syft (Syft wird bereits in Aufgabe 7 für ein anderes Image verwendet, hier wird ausdrücklich Trivy verlangt). Das Skalieren erfolgt über `kubectl scale deployment/<name> -n cks-111 --replicas=0` (oder `--replicas=1` für die zu behaltenden).
</details>

---
| **2** | **Ursprüngliche Berichte der statischen Analyse** |
| :---: | :--- |
| Was wir tun | • VOR den Korrekturen (ohne eine dieser drei Dateien nach Beginn von Aufgabe 3 anzufassen) speichere die Ergebnisse: Hadolint in `2/hadolint-before.txt`, kubesec JSON in `2/kubesec-before.json`, kube-linter JSON in `2/kube-linter-before.json`.<br/>• Starte sie direkt gegen die URSPRÜNGLICHEN Start-`Dockerfile`/`deployment.yaml`.<br/>• Verstecke Fehler in den Berichtsdateien nicht über `\|\| true`: Ein Exit-Code ungleich null des Linters wird erwartet. |
| Abnahmekriterien | • **Artifacts:** alle drei existieren; Hadolint enthält findings, kubesec enthält `scoring`, kube-linter ist ein gültiges KubeLinter-JSON-Objekt mit den Feldern `Reports` und `Summary`; vor den Korrekturen enthält `Reports` findings.<br/>• **Abgleich mit der Baseline:** Der Checker vergleicht den Inhalt aller drei artifacts mit seiner eigenen Baseline, die beim provisioning gegen die ursprünglichen Startdateien aufgenommen wurde, BEVOR sie dem Teilnehmer ausgegeben wurden.<br/>• Ein von Hand geschriebener, aber syntaktisch gültiger Bericht besteht nicht. |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Ein Exit-Code ungleich null vom Linter bei gefundenen Problemen ist ERWARTETES Verhalten und kein Fehler deines Befehls. Wenn du den Aufruf in `|| true` einpackst, nur damit das Skript nicht mit `set -e` stehen bleibt, stelle sicher, dass die Ausgabe des Befehls trotzdem in der Datei gespeichert wird (über `tee` oder eine Umleitung VOR `|| true`) und nicht verloren geht.
</details>

---
| **3** | **Dockerfile anhand der findings korrigieren** |
| :---: | :--- |
| Was wir tun | • Korrigiere `/home/ubuntu/cks-111/Dockerfile`: Lege das Basis-Image mit der immutable reference `nginx:1.27.3-alpine@sha256:<manifest-digest>` fest.<br/>• Verwende kein `ADD` mit URL, speichere keinen token in `ENV`, installiere kein `sudo`.<br/>• Füge einen unprivilegierten `USER` hinzu (uid nicht `0`). Verwende `COPY` und eine reproduzierbare Paketinstallation nur bei Bedarf.<br/>• Füge `ARG CKS_SIGNATURE_TEST=signed` und `LABEL cks.signature-test=$CKS_SIGNATURE_TEST` neben den übrigen Anweisungen hinzu - das ist der einzige Punkt eines kontrollierten Unterschieds des Images, der in Aufgabe 9c gebraucht wird, um einen anderen digest zu garantieren, ohne die hier geprüften security-Eigenschaften zu ändern.<br/>• Speichere nach der Korrektur die erfolgreiche Hadolint-Ausgabe in `3/hadolint-after.txt`. |
| Abnahmekriterien | • **Dockerfile:** kein `latest`, das remote `ADD` ist entfernt, kein `API_TOKEN`/`TOKEN` mehr vorhanden, ein non-root `USER` ist vorhanden, `ARG CKS_SIGNATURE_TEST` und `LABEL cks.signature-test` sind vorhanden.<br/>• **Hadolint:** Der finale Bericht enthält nicht `DL3007`, `DL3013`, `DL3020`, `DL3045`. |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

`ARG`/`LABEL` für `CKS_SIGNATURE_TEST` kann scheinbar nichts mit den aktuellen findings von Hadolint zu tun haben - das wird extra hier vorab hinzugefügt, damit Aufgabe 9c (viel später) über `--build-arg` ein physisch anderes Image bauen kann, ohne das Dockerfile erneut umzuschreiben. Füge diese beiden Zeilen jetzt hinzu, auch wenn ihr Nutzen erst in 9c klar wird.
</details>

---
| **4** | **Workload YAML anhand von kubesec und kube-linter korrigieren** |
| :---: | :--- |
| Was wir tun | • Baue und veröffentliche zuerst das hardened image aus Aufgabe 3 und gib dann in `deployment.yaml` seine immutable manifest reference `registry/.../catalog@sha256:<manifest-digest>` an (nicht das upstream nginx).<br/>• Füge auf Pod-Ebene `automountServiceAccountToken: false`, `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` hinzu.<br/>• Setze im Container `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`, requests/limits für CPU und memory.<br/>• Mounte für nginx ein beschreibbares `emptyDir`/tmpfs in temp-, pid/run-, cache- und config-Pfade und bereite die config vor dem Start vor.<br/>• Entferne `privileged`, wende das Deployment an, bestätige Ready/Available und einen erfolgreichen HTTP request.<br/>• Speichere die neuen Berichte `4/kubesec-after.json` und `4/kube-linter-after.json`. |
| Abnahmekriterien | • **Image:** Das YAML verwendet ein digest-pinned hardened image mit `USER 101` und nicht das upstream nginx.<br/>• **Manifest:** Die erforderlichen Felder, der init container `prepare-nginx-config` und die beschreibbaren mounts sind vorhanden; `privileged` fehlt.<br/>• **Funktionsfähigkeit:** Das Deployment ist Available und der HTTP request erfolgreich.<br/>• **Berichte:** Beide finalen Berichte sind gültiges JSON. |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

`readOnlyRootFilesystem: true` erfordert beschreibbare Pfade für JEDES Verzeichnis, in das nginx gewöhnlich schreibt: `/tmp`, `/var/run` (PID-Datei), `/var/cache/nginx` (Cache) und `/etc/nginx/conf.d` (wenn die config beim Start erzeugt wird). Lässt man auch nur einen aus, startet der Container zwar, scheitert aber beim ersten Versuch von nginx, dort etwas zu schreiben. Der Init container `prepare-nginx-config` wird gebraucht, um die Standardkonfiguration in ein separates beschreibbares Volume zu kopieren, BEVOR der Hauptcontainer startet - genau deshalb wird er in den Abnahmekriterien gesondert erwähnt.
</details>

---
| **5** | **Suche nach Paketversionen** |
| :---: | :--- |
| Was wir tun | • Verwende Trivy im Modus der Liste aller Pakete für `$IMAGE`.<br/>• Speichere den Befehl, die immutable image reference, das kanonische `nginx@sha256:<manifest-digest>` aus `Metadata.RepoDigests[0]` und mindestens drei Zeilen `name=version` in `/var/work/tests/artifacts/5/version-search.txt`.<br/>• Ersetze die Suche nicht durch eine manuelle Liste: In der evidence muss die Befehlszeile mit `trivy image --list-all-pkgs` stehen. |
| Abnahmekriterien | • **Artifact:** enthält den Befehl, das immutable `nginx:1.27.3-alpine@sha256:...`, `repo_digest=nginx@sha256:...` von Trivy und mindestens drei Paare package/version.<br/>• **Frische Prüfung:** Der Checker wiederholt `trivy image --list-all-pkgs` für dasselbe Image selbstständig und verlangt, dass `repo_digest=` und mindestens drei gespeicherte Paare `name=version` mit diesem frischen Scan übereinstimmen.<br/>• Eine von Hand geschriebene, aber syntaktisch plausible Liste besteht nicht. |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

Das Flag heißt genau `--list-all-pkgs` und nicht `--list-packages` oder eine ähnliche Variante - prüfe den exakten Namen des Flags in `trivy image --help`, wenn der Befehl nicht funktioniert. Speichere die ECHTE Ausgabe des Befehls in der Datei (zum Beispiel über `tee`), tippe nicht einige Zeilen package=version von Hand „aus dem Gedächtnis“ ab - der Test sucht die Zeile mit dem Befehl selbst als Beleg, dass die Daten vom Werkzeug stammen.
</details>

---
| **5b** | **Eine Paketversion in workload images finden und problematische Container entfernen** |
| :---: | :--- |
| Was wir tun | • Im Namespace `cks-111` ist bereits das Deployment `pkg-audit-app` mit drei Containern (`c1`, `c2`, `c3`) ausgerollt, jeder mit seinem eigenen immutable digest-pinned image.<br/>• In genau zwei der drei Images ist ein und dasselbe Paket einer konkreten Version vorhanden - die für deine Instanz des Labs vorgegebenen `TARGET_PACKAGE`/`TARGET_VERSION` werden beim provisioning dynamisch bestimmt, es gibt keine fest eingetragenen Werte.<br/>• Hole alle drei image references aus dem live Deployment und führe für jede `bom generate` aus (speichere jedes SBOM separat in `/var/work/tests/artifacts/5b/bom/`).<br/>• Bestimme, welche zwei Container tatsächlich dasselbe package/version enthalten, und schreibe das gefundene Paar in `5b/answer.txt` als `TARGET_PACKAGE=<name>` und `TARGET_VERSION=<version>`.<br/>• Entferne GENAU diese zwei offending Container aus dem Deployment (über `kubectl edit`/`kubectl apply` eines korrigierten Manifests), so dass nur der „saubere“ Container übrig bleibt und das Deployment `Available` bleibt. |
| Abnahmekriterien | • **Antwort:** `answer.txt` nennt ein echtes package/version, das in genau zwei der drei ursprünglichen Images vorhanden ist (nicht geraten). Diese beiden Images haben viele gemeinsame Pakete: Es passt jedes beliebige einzelne Paar `name=version`, das im dritten Image nicht vorhanden ist.<br/>• **SBOM:** In `5b/bom/` gibt es mindestens eine echte Ausgabe von `bom generate`, die diesen Fund bestätigt.<br/>• **Unabhängige Prüfung:** Der Checker führt `bom generate` unabhängig für die ursprünglichen candidate images (beim provisioning gespeichert) aus und gleicht deine Antwort mit diesem unabhängigen Lauf ab.<br/>• **Deployment:** Das finale Deployment enthält nur den „sauberen“ Container und bleibt `Available`. |

<details>
<summary>💡 Hinweis zu Aufgabe 5b</summary>

Der Befehl ist `bom generate --format json --output <file> --image <ref>` für JEDE der drei image references einzeln. Vergleiche die SBOMs paarweise: Ein Paket gilt als „offending“, wenn dasselbe Paar `name`/`versionInfo` im SBOM zweier Container vorkommt, aber im dritten fehlt (oder eine andere Version hat). Versuche nicht, nach Name/Tag des Images zu raten - einige Paare von Images können „ähnlich“ aussehen, aber die tatsächliche Übereinstimmung des Pakets wird nur durch den Vergleich der echten SBOMs bestimmt. Wenn du das Deployment bearbeitest, entferne den Container vollständig aus `spec.template.spec.containers` und ändere nicht einfach sein Image.
</details>

---
| **6** | **SPDX SBOM über bom** |
| :---: | :--- |
| Was wir tun | • Erzeuge ein SPDX JSON SBOM mit dem Werkzeug `bom` genau für das immutable `$IMAGE` (dasselbe `tag@digest`, das in Aufgabe 1 verwendet wurde, und nicht den bare tag `nginx:1.27.3-alpine`); speichere es in `/var/work/tests/artifacts/6/bom.spdx.json`.<br/>• Schreibe in die Datei `6/bom-command.txt` den ausgeführten Befehl mit dem exakten `--image $IMAGE`. |
| Abnahmekriterien | • **SBOM:** gültiges JSON, hat `spdxVersion`, enthält das Array `packages`; eines der top-level Pakete, auf die `documentDescribes` verweist, identifiziert DENSELBEN manifest digest wie `$IMAGE` aus Aufgabe 1 (über `versionInfo`/`name`).<br/>• **Befehl:** `bom-command.txt` enthält das exakte immutable `$IMAGE` und verwendet `bom generate`.<br/>• Ein SBOM für ein anderes Image (nicht mit `$IMAGE` aus Aufgabe 1 verbunden) besteht nicht, selbst wenn `bom-command.txt` gefälscht ist.<br/>• **Frische Prüfung:** Der Checker erzeugt das SBOM zusätzlich selbstständig mit demselben `bom` für dasselbe Image neu und verlangt, dass die Menge der Pakete (`name`/`versionInfo`) in deinem SBOM mit diesem frischen Lauf übereinstimmt - ein von Hand geschriebenes minimales SPDX-Dokument mit einem top-level Paket besteht nicht. |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

Der Befehl `bom generate -o <output.json> -i <image>` - unbedingt mit dem Flag `-o` zur Angabe der Ausgabedatei, sonst geht die Ausgabe nach stdout. Das Ausgabeformat von `bom` ist sein EIGENES SPDX JSON, das sich in Details von dem SPDX unterscheidet, das Syft erzeugen kann - verwechsle diese zwei verschiedenen Werkzeuge nicht bei der Erzeugung desselben Standardformats.
</details>

---
| **7** | **CycloneDX SBOM über Syft und Cosign-Prüfung** |
| :---: | :--- |
| Was wir tun | • Erzeuge ein CycloneDX JSON SBOM von Syft für dasselbe immutable `$IMAGE` (`nginx:1.27.3-alpine@sha256:<manifest-digest>`) aus Aufgabe 1 und speichere es in `7/syft.cdx.json`.<br/>• Prüfe dann die Signatur des öffentlichen Images `gcr.io/distroless/static-debian13:nonroot` über keyless Cosign und speichere die vollständige erfolgreiche Ausgabe in `7/cosign-verify.txt`.<br/>• Verwende für Distroless den issuer `https://accounts.google.com` und die identity `keyless@distroless.iam.gserviceaccount.com`. |
| Abnahmekriterien | • **Syft SBOM:** `bomFormat: CycloneDX`, nicht leeres `components`, `metadata.component.type == "container"` und `metadata.component.version` gleich dem manifest digest desselben `$IMAGE` aus Aufgabe 1 - ein SBOM für ein anderes Image (bare tag, alpine, busybox usw.) besteht nicht.<br/>• **Cosign:** ein echter Befehl `cosign verify` für `gcr.io/distroless/static-debian13:nonroot` (das ist der aktuelle unterstützte Tag; `gcr.io/distroless/static:nonroot` ohne das Suffix `-debian13` gilt laut dem offiziellen README von Distroless als deprecated und wird nicht mehr aktualisiert) mit den angegebenen issuer/identity endet mit exit code `0`, und die vollständige Ausgabe ist in `7/cosign-verify.txt` gespeichert.<br/>• **Frische Prüfung:** Der Checker erzeugt das SBOM zusätzlich selbstständig mit demselben Syft für dasselbe Image neu und verlangt, dass die Menge der Komponenten (`name`/`version`) in deinem SBOM mit diesem frischen Lauf übereinstimmt - ein von Hand geschriebenes minimales CycloneDX-Dokument mit einer top-level Komponente besteht nicht. |

<details>
<summary>💡 Hinweis zu Aufgabe 7</summary>

Syft erzeugt CycloneDX über das Flag `-o cyclonedx-json` (nicht mit der SPDX-Ausgabe desselben Werkzeugs verwechseln). Für die keyless verification von Distroless wird WEDER ein Schlüssel NOCH `cosign generate-key-pair` gebraucht - verwende `cosign verify --certificate-identity <identity> --certificate-oidc-issuer <issuer>` mit den EXAKTEN issuer/identity-Strings aus der Aufgabe - ein Tippfehler in einem von ihnen führt zu einem Verifikationsfehler.
</details>

---
| **8** | **`trivy sbom`: Scan einer fertigen SBOM-Datei auf Schwachstellen** |
| :---: | :--- |
| Was wir tun | • Das CycloneDX SBOM aus Aufgabe 7 (`7/syft.cdx.json`) beschreibt die Zusammensetzung des Images und seines OS, enthält aber von sich aus keine Aussage zu Schwachstellen.<br/>• Scanne genau diese SBOM-Datei (nicht das Image direkt) mit dem Werkzeug `trivy sbom` und speichere das strukturierte JSON in `/var/work/tests/artifacts/8/sbom-scan.json`.<br/>• Der Befehl muss die SBOM-Datei explizit als Eingabe akzeptieren und nicht `$IMAGE` neu scannen; speichere seinen Text in `/var/work/tests/artifacts/8/sbom-scan-command.txt`. |
| Abnahmekriterien | • **Datei:** nicht leer, das JSON wird von `jq` geparst, `ArtifactType` = `cyclonedx`, `Results` ist nicht leer und enthält gefundene Schwachstellen.<br/>• **Befehl:** `sbom-scan-command.txt` enthält den Befehl `trivy sbom` mit dem Pfad zu `7/syft.cdx.json`.<br/>• **Frische Prüfung:** Der Checker wiederholt `trivy sbom` für diese Datei selbst. |

<details>
<summary>💡 Hinweis zu Aufgabe 8</summary>

Der Befehl ist `trivy sbom <Pfad-zur-sbom-Datei>` und NICHT `trivy image <Pfad-zur-Datei>` - das sind verschiedene Unterbefehle mit unterschiedlicher Eingabelogik. Wenn du versehentlich den Pfad der SBOM-Datei an `trivy image` übergibst, versucht Trivy, ihn als Namen einer image reference zu interpretieren, und endet mit einem Fehler oder unerwartetem Verhalten.
</details>

---
| **9a** | **Kyverno: installieren und `ImageValidatingPolicy` auf trusted signature erstellen** |
| :---: | :--- |
| Was wir tun | • Installiere Kyverno über `install-kyverno` und warte auf die Bereitschaft des `admission controller`.<br/>• Erzeuge ein lokales Schlüsselpaar mit `cosign generate-key-pair` (Übungs-Schlüsselpaar, kein production key).<br/>• Signiere dein **eigenes** hardened image aus Aufgabe 4 (`$HARDENED_IMAGE`, nicht das upstream nginx) mit deinem private key und speichere die Ausgabe von `cosign sign` in `9a/cosign-sign.txt`.<br/>• Erstelle die `ImageValidatingPolicy` `require-signed-catalog-images`, die `verifyImageSignatures` mit deinem public key für alle Pods mit einem Image im repository deines `$HARDENED_IMAGE` prüft, einschließlich `pods/ephemeralcontainers` UPDATE und aller container lists, und unsignierte/ungültig signierte Images **ablehnt** (`validationActions: [Deny]`). |
| Abnahmekriterien | • **Kyverno:** installiert, sein admission controller ist `Available`.<br/>• **Signatur:** `9a/cosign-sign.txt` enthält die erfolgreiche Ausgabe der Signierung genau von `$HARDENED_IMAGE`; der echte Befehl `cosign verify --key cosign.pub "$HARDENED_IMAGE"` endet erfolgreich.<br/>• **Policy:** Die angewendete `ImageValidatingPolicy require-signed-catalog-images` existiert, hat `apiVersion: policies.kyverno.io/v1`, `validationActions: [Deny]`, public key und `verifyImageSignatures`.<br/>• **Geltungsbereich:** Die `matchImageReferences` der policy sind genau auf `$HARDENED_REPO:*` und `$HARDENED_REPO@*` begrenzt und nicht auf das unsichere Präfix `$HARDENED_REPO*`. |

<details>
<summary>💡 Hinweis zu Aufgabe 9a</summary>

`cosign generate-key-pair` erstellt `cosign.key`/`cosign.pub` im aktuellen Verzeichnis - ein Übungs-Schlüsselpaar, das an keinen OIDC issuer gebunden ist, anders als die keyless verification aus Aufgabe 7. Speichere den private key außerhalb von `/home/ubuntu/cks-111`, weil dieses Verzeichnis in Aufgabe 9c erneut als Docker build context verwendet wird - ein darin zurückgelassenes `cosign.key` gelangt über `COPY . /usr/share/nginx/html` direkt in das Dateisystem des veröffentlichten Images. `matchImageReferences` in der policy muss ihre Wirkung GENAU auf dein repository (`$HARDENED_REPO`) begrenzen und nicht auf den gesamten Cluster - sonst blockiert die policy ALLE Pods ohne Signatur, einschließlich der Systemkomponenten von Kubernetes.
</details>

---
| **9b** | **Fresh signed ALLOW: neuer Pod nach dem Erstellen der policy** |
| :---: | :--- |
| Was wir tun | • Die policy aus Aufgabe 9a muss das signierte `$HARDENED_IMAGE` zulassen - aber ein erneutes `kubectl apply` eines bereits vorhandenen Deployments **beweist** das **nicht**: Wenn sich das template nicht geändert hat, wird möglicherweise kein neues ReplicaSet/Pod erstellt, und `Running` ist einfach der alte Pod, der vor der policy erstellt wurde.<br/>• Erstelle ein **neues**, zuvor nicht existierendes Objekt: `kubectl run signed-admission-check -n cks-111 --image="$HARDENED_IMAGE" --restart=Never --command -- sleep 3600`.<br/>• Speichere `creationTimestamp` dieses Pods, `creationTimestamp` der policy aus 9a und die finalen Werte von `status.phase` und der `Ready` condition in `9b/signed-admission-check.json`. |
| Abnahmekriterien | • **Pod:** `signed-admission-check` existiert und verwendet genau `$HARDENED_IMAGE`; für ihn läuft `cosign verify --key cosign.pub "$HARDENED_IMAGE"` erfolgreich, `status.phase` ist nicht `Failed`, und die `Ready` condition erreicht `True`.<br/>• **Artifact:** `9b/signed-admission-check.json` enthält dieses Image und `creationTimestamp` des Pods **nicht früher** als `creationTimestamp` der `ImageValidatingPolicy require-signed-catalog-images`.<br/>• Das belegt die fresh post-policy admission genau eines nachprüfbar signierten Images und nicht eines die policy überlebenden alten Pods. |

<details>
<summary>💡 Hinweis zu Aufgabe 9b</summary>

Verwende das Deployment `catalog` aus Aufgabe 4 für diese Prüfung nicht erneut - verwende buchstäblich ein neues `kubectl run` mit einem neuen Pod-Namen, wie in der Aufgabe angegeben. Beide timestamps (Pod und policy) sind ISO8601-Strings in UTC, man kann sie lexikografisch wie gewöhnliche Strings vergleichen (`[[ "2026-09-06T10:05:00Z" > "2026-09-06T10:00:00Z" ]]` funktioniert in bash für dieses Format korrekt).
</details>

---
| **9c** | **Signature-specific DENY: unsigned digest, der tatsächlich im selben repository existiert** |
| :---: | :--- |
| Was wir tun | • Baue und veröffentliche einen **zweiten** Tag im selben repository wie `$HARDENED_IMAGE` (zum Beispiel `${HARDENED_TAG%:*}:unsigned-1.0`), ohne ihn zu signieren.<br/>• Dieses Image muss ein **physisch anderes artifact** sein und nicht derselbe digest wie das bereits signierte `$HARDENED_IMAGE`: Wenn man dasselbe `Dockerfile`/denselben context ohne Änderungen baut, kann ein reproducible/cached build einen identischen digest ergeben, und dann zeigt der „unsigned“ Tag tatsächlich auf ein bereits signiertes artifact, und `cosign verify` besteht unerwartet.<br/>• Führe über build-arg einen kontrollierten Unterschied ein (zum Beispiel `--build-arg CKS_SIGNATURE_TEST=unsigned-1` mit entsprechendem `ARG`/`LABEL` im Dockerfile) und speichere den Nachweis `$UNSIGNED_DIGEST != $HARDENED_DIGEST` explizit in `9c/digest-comparison.txt`.<br/>• Hole den registry manifest digest auf dieselbe Weise wie in Aufgabe 3 (`podman push --digestfile`), bilde `$UNSIGNED_IMAGE` im selben repository.<br/>• Belege explizit, dass dieser digest **existiert und pullable ist** (eine Anfrage `HEAD` oder `GET` an `/v2/catalog/manifests/<digest>` in der Registry ist erfolgreich) und **keine** gültige Signatur mit deinem Schlüssel hat (`cosign verify --key cosign.pub "$UNSIGNED_IMAGE"` endet mit einem Fehler) - speichere beide Ausgaben in `9c/unsigned-exists.txt` und `9c/unsigned-not-signed.txt`.<br/>• Erstelle dann den Pod `catalog-unsigned-probe` mit diesem `$UNSIGNED_IMAGE` und speichere das admission denial in `9c/admission-deny.txt`. |
| Abnahmekriterien | • **Artifact:** `9c/digest-comparison.txt` enthält `hardened_digest=`, `unsigned_digest=` und `unsigned_image=` (vollständige `tag@digest`-Referenz im selben repository wie `$HARDENED_IMAGE`, mit genuinely anderem digest).<br/>• **Prüfung des Checkers:** Er löst `unsigned_image` selbst in der Registry auf, bestätigt das Fehlen einer gültigen Signatur über sein eigenes `cosign verify`, erstellt SEINEN eigenen neuen Pod mit diesem Image und verlangt die eindeutige validation message seiner eigenen policy: `catalog image must have a valid release signature`.<br/>• Nur diese Meldung zählt, nicht irgendein admission-Fehler: Ein generischer admission/signature-Fehler einer anderen policy ergibt kein PASS, `manifest unknown`/registry-lookup-Fehler genügen ebenfalls nicht.<br/>• Von Hand geschriebene evidence-Dateien ohne echte admission control ergeben kein PASS - der Checker vertraut keinen Textdateien, außer `unsigned_image=` als Zeiger auf ein echtes zu prüfendes Image. |

<details>
<summary>💡 Hinweis zu Aufgabe 9c</summary>

Die Reihenfolge der Nachweise ist für ihre Glaubwürdigkeit wichtig: Belege zuerst, dass `$UNSIGNED_IMAGE` EXISTIERT und PULLABLE ist (sonst kann das spätere denial einfach „manifest unknown“ sein und nicht die Signatur betreffen), dann belege das FEHLEN der Signatur, und erst DANACH versuche, den Pod zu erstellen. Wenn der Vergleich der digests in `digest-comparison.txt` eine Übereinstimmung zeigt - sorge für einen echten Unterschied im content (ändere zum Beispiel das build-arg `CKS_SIGNATURE_TEST` auf einen anderen Wert und baue neu).
</details>

## Prüfung

```bash
check_result
```

Die Prüfung enthält `Init` und vierzehn unabhängige Bewertungstests (Aufgabe 9 ist in 9a/9b/9c aufgeteilt). Sie prüft den Inhalt der Dateien und
JSON und nicht nur das Vorhandensein von Namen. Externe Registry-Anfragen sind für Trivy, SBOM und
Cosign erforderlich; wenn die Registry vorübergehend nicht verfügbar ist, wiederhole genau den entsprechenden Befehl.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=111 make delete_cks_task
```
