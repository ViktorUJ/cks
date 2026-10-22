[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 104 - Zugriff auf die Kubernetes API einschränken: RBAC, ServiceAccount und anonymous-auth

## Ziel

In diesem CKS-Lab schränkst du den Zugriff auf die Kubernetes API nach dem Prinzip der geringsten
Privilegien ein. Die Praxis umfasst minimales namespaced RBAC, moderne
kurzlebige ServiceAccount-token, einen Pod ohne API-token, das Entfernen veralteter
übermäßiger Berechtigungen und das Deaktivieren des anonymen Zugriffs auf den API server.

Arbeite nur mit den in den Aufgaben genannten Objekten. Der Namespace `security-104` und
die absichtlich gefährliche Bindung `legacy-operator-admin` wurden vom Start-Skript bereits vorbereitet, ebenso
die fixtures für die Aufgaben 10-12: das Secret `legacy-config`, die Namespaces `rbac-a`/`rbac-b` und der
Namespace `development`. Das ist eine Lernkonfiguration und kein Beispiel für production.

## Threat model

Nehmen wir an, dass ein Angreifer bereits Code in einem Pod ausführt und versucht, die identity des workloads oder das Fehlen von authentication zu nutzen, um sich zur Kubernetes API vorzuarbeiten. In diesem Fall ist nicht nur der initiale Zugriff wichtig, sondern auch der blast radius nach dem compromise.

Aufgabe 1 schließt den übermäßigen RBAC scope, Aufgabe 2 - den langlebigen token, und Aufgabe 3 - den unnötigen API-Zugriff aus dem Pod. Das verringert die Möglichkeiten, die identity des workloads nach dem compromise zu nutzen.

Aufgabe 4 beseitigt wildcard cluster-wide Rechte, und Aufgabe 5 - anonymous access. Jeder dieser Pfade kann für sich genommen den blast radius bis zur Kubernetes API ausweiten.

Aufgabe 6 schließt einen eigenen Leckpfad: Ein über eine environment variable übergebenes Secret wird Teil der Umgebung des Prozesses und kann von jedem Prozess mit `exec`-Zugriff auf den Container aus `/proc/1/environ` gelesen werden, und es kann in application logs, crash dumps oder andere diagnostische Ausgaben gelangen, wenn das Programm selbst oder das Diagnosewerkzeug das environment ausgibt. `kubectl describe pod` zeigt für `env` mit `secretKeyRef` nur den Verweis auf das Secret und seinen Schlüssel (`<set to the key ... in secret ...>`), für `envFrom` mit `secretRef` nur den Namen des Secrets, aber nicht den resolved Wert - verwechsle diesen Verweis nicht mit einem Leck des Wertes selbst. Ein Volume mount mit `defaultMode: 0400` beseitigt nicht den Zugriff des berechtigten Prozesses im Container auf den Wert, entfernt aber das Secret aus der Umgebung des Prozesses und beschränkt die Dateirechte zum Lesen auf den Eigentümer.

Aufgabe 7 schließt versteckte Pfade der RBAC privilege escalation: `impersonate`, `bind`/`escalate` und CSR approval erweitern die Liste der verfügbaren Ressourcen nicht direkt, sondern geben die Möglichkeit, im Namen eines anderen zu handeln oder sich selbst umfassendere Rechte zu geben - das ist eine eigene Risikokategorie im Unterschied zum wildcard `*` aus Aufgabe 4. Aufgabe 8 sorgt für einen systemischen statt punktuellen Schutz: automount auf Ebene von Namespace/default SA wirkt auch für einen Pod, bei dem der Entwickler vergessen hat, den token explizit zu deaktivieren.

Aufgabe 9 zeigt, dass Prävention (Aufgaben 1-8) und Erkennung verschiedene, sich ergänzende Schichten sind. Selbst wenn die konkreten Eskalationspfade in Aufgabe 7 geschlossen sind, braucht es für einen künftigen Vorfall eine Möglichkeit, eine **gefährliche RBAC-Änderung** zu sehen (zum Beispiel eine fehlerhafte oder böswillige Vergabe von `cluster-admin` an jemanden), ohne ständiges manuelles `kubectl get`: Der audit log liefert reproduzierbare forensic evidence darüber, wer genau die Änderung ausgelöst hat, und nicht nur einen aktuellen Snapshot des RBAC-Zustands.

ATT&CK T1528 (Steal Application Access Token) und T1613 liefern den Kontext für dieses Szenario: Die Aufgaben modellieren keinen einzelnen Angriff, sondern begrenzen die Folgen eines bereits kompromittierten workloads.

Die Aufgaben 10-12 decken drei grundlegende, in der Prüfung häufig vorkommende Workflows ab und keine neuen Bedrohungen: Aufgabe 10 - sichere Wiederverwendung eines vorhandenen Secrets ohne case-by-case hardcoding von Werten in Manifesten; Aufgabe 11 - punktuelle Reparatur einer übermäßigen Role und korrekte cross-namespace RBAC-Bindung, bei der man sich leicht im scope irrt; Aufgabe 12 - vollständiges onboarding eines neuen Benutzers über ein Zertifikat, vom private key bis zum prüfbaren Zugriff, und nicht nur die Analyse einer fertigen kubeconfig.

## Prüfe dich vor dem Start

Bevor du `check_result` öffnest, vergewissere dich, dass du diese Fragen sicher beantworten kannst. Wenn nicht - kehre zu [Kapitel 10](../../course/10/de.md) (RBAC), [Kapitel 11](../../course/11/de.md) (ServiceAccounts) und [Kapitel 12](../../course/12/de.md) (Einschränkung des Zugriffs auf die API) zurück.

<details>
<summary>1. Wie unterscheiden sich `Role`+`RoleBinding` von `ClusterRole`+`ClusterRoleBinding` im Kontext von Aufgabe 1?</summary>

Eine `Role` gilt nur in einem Namespace, aber ihr `RoleBinding` KANN auf ein Subjekt (zum Beispiel einen ServiceAccount) aus JEDEM anderen Namespace verweisen - Kubernetes unterstützt offiziell ein `subjects[].namespace`, das vom Namespace des `RoleBinding` selbst abweicht. Was fest bleibt, ist der SCOPE der vergebenen Rechte: Die Rechte gelten nur im Namespace, in dem das `RoleBinding` erstellt wurde, unabhängig davon, woher das Subjekt stammt. Ein `RoleBinding` kann auch auf eine `ClusterRole` verweisen (nicht nur auf eine `Role`) - dann erhält man Rechte aus einer cluster-wide Vorlage, die aber nur im Namespace des konkreten `RoleBinding` vergeben werden. `ClusterRole`+`ClusterRoleBinding` gibt Zugriff auf den gesamten Cluster. Aufgabe 1 verlangt minimalen **namespaced** Zugriff, daher `Role` und nicht `ClusterRole` - sonst ist der scope weiter als erforderlich.
</details>

<details>
<summary>2. Warum gilt ein bound projected token (Aufgabe 2) als sicherer als ein legacy Secret-based token?</summary>

Ein bound projected token ist kurzlebig (festgelegt durch `expirationSeconds`), läuft automatisch ab und wird vom kubelet rotiert und ist an einen konkreten Pod gebunden - wird der Pod gelöscht, wird der token ungültig. Ein legacy Secret-token hat keine expiration, wird als gewöhnliches `Secret` in etcd gespeichert und bleibt unbegrenzt gültig, auch wenn der Pod nicht mehr existiert.
</details>

<details>
<summary>3. Worin besteht der Unterschied zwischen dem, was `automountServiceAccountToken: false` auf Pod-Ebene und auf ServiceAccount-Ebene bewirkt?</summary>

Auf ServiceAccount-Ebene ist das eine Baseline: Der Wert gilt für alle Pods, die diesen SA verwenden, solange der Pod ihn nicht explizit überschreibt. Auf Pod-Ebene ist das ein Override: Ein explizites Feld in der Pod spec hat Vorrang vor dem Wert des SA. Aufgabe 8 prüft gezielt die Baseline auf Ebene von SA/Namespace, und die Aufgaben 2-3 - die explizite Einstellung auf Ebene des konkreten Pods.
</details>

<details>
<summary>4. Warum gehören `impersonate`/`bind`/`escalate` (Aufgabe 7) nicht zur selben Risikoklasse wie das wildcard `*` (Aufgabe 4)?</summary>

Ein wildcard `*` in `resources`/`verbs` erweitert direkt die **Liste der verfügbaren Operationen und Ressourcen**. `impersonate`/`bind`/`escalate` geben von sich aus keinen Zugriff auf neue Ressourcen - sie geben die Möglichkeit, **im Namen eines anderen zu handeln** (`impersonate`) oder **sich selbst Rechte zu geben, die man ursprünglich nicht hatte** (`bind`/`escalate`). Das ist eine eigene Kategorie der privilege escalation, die man bei einem RBAC-Audit leicht übersieht, wenn man nur auf `verbs`/`resources` schaut, ohne diese drei besonderen Verben zu berücksichtigen.
</details>

## Infrastruktur

Die Umgebung wird über Terragrunt in AWS `eu-central-1` ausgerollt:

| Komponente | Zweck |
|---|---|
| `vpc` | VPC `10.10.0.0/16` mit öffentlichen Subnetzen |
| `ssh-keys` | Schlüssel für den Zugriff auf die Nodes |
| `k8s-1` | Ein-Node-kubeadm-Cluster Kubernetes `1.36.0`, containerd und **Calico** |
| `worker` | Arbeitsmaschine mit eingerichtetem `kubectl` und `check_result` |

Die control-plane erlaubt gewöhnliche Pods, daher wird kein separater worker-Node benötigt.
Für Aufgabe 5 wird SSH-Zugriff auf die control-plane benötigt: Dort liegt das Manifest des
static Pods des API server.

## Bereitstellung

```bash
TASK=104 make run_cks_task
```

Verbinde dich per SSH mit der Arbeitsmaschine. Der Kontext `cluster1-admin@cluster1` ist bereits eingerichtet.

```bash
time_left
check_result
```

## Aufgaben

---
| **1** | **Minimales RBAC zum Lesen von Pods** |
| :---: | :--- |
| Was wir tun | Erstelle im Namespace `security-104` den ServiceAccount `auditor`, die Role `pod-observer` und das RoleBinding `auditor-pod-observer`. Die Role muss **nur** `get`, `list`, `watch` auf die Ressource `pods` der core API erlauben. Binde sie nur an den ServiceAccount `auditor`. |
| Abnahmekriterien | Die Role enthält genau eine Regel für `pods` mit den Verben `get`, `list`, `watch`; das RoleBinding verweist auf diese Role und den ServiceAccount `auditor`; im Namen von `auditor` kann man keine `secrets` löschen. |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

Ein häufiger Fehler ist, überflüssige Verben hinzuzufügen (zum Beispiel `create` „zur Sicherheit“) oder eine `ClusterRole` statt einer `Role` zu verwenden. Prüfe dich selbst: `kubectl auth can-i list pods -n security-104 --as=system:serviceaccount:security-104:auditor` muss `yes` zurückgeben, und `kubectl auth can-i delete secrets -n security-104 --as=system:serviceaccount:security-104:auditor` - `no`. Wenn Role und RoleBinding in verschiedenen Namespaces liegen, wirkt die Bindung nicht - das `RoleBinding` muss im selben Namespace wie die `Role` liegen, und das Subjekt darin muss in `name`/`namespace` exakt übereinstimmen.
</details>

---
| **2** | **Kurzlebiger projected ServiceAccount token** |
| :---: | :--- |
| Was wir tun | Erstelle den ServiceAccount `api-client` und den Pod `token-client` in `security-104`. Verwende keinen legacy Secret-token. Deaktiviere das übliche automount des tokens und mounte den benötigten token über **genau eine** projected `serviceAccountToken` source nach `/var/run/secrets/tokens/api-token` mit `path: api-token` und `expirationSeconds` von `600` bis `3600` einschließlich - füge keine zusätzlichen `serviceAccountToken` sources in dasselbe (oder ein anderes) projected volume ein. **Setze keine `audience`**, damit das kubelet den Standard-identifier des API server anfordert. Wenn die Anwendung eine eigene audience benötigt, gleiche sie zuerst mit `--api-audiences` (oder dem default aus `--service-account-issuer`) auf dem API server ab und setze sie erst dann explizit. |
| Abnahmekriterien | Der Pod verwendet `api-client`, hat `automountServiceAccountToken: false` und enthält **genau eine** projected `serviceAccountToken` source in der gesamten Pod-Spezifikation - ohne fest vorgegebene audience, mit dem angegebenen path und `expirationSeconds` im Bereich `600`-`3600` (beide Grenzen einschließlich). Ein TokenReview, ausgeführt aus dem admin-Kontext für den gemounteten token, liefert `authenticated: true` und den Namen `system:serviceaccount:security-104:api-client`; eine separate RBAC-Prüfung bestätigt, dass dieser ServiceAccount keine `secrets` löschen kann. |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Die genaue Syntax von `projected.sources[].serviceAccountToken` musst du nicht auswendig kennen - auf `kubernetes.io/docs` gibt es ein fertiges Beispiel: Concepts → Storage → [Projected Volumes](https://kubernetes.io/docs/concepts/storage/projected-volumes/), Abschnitt **„serviceAccountToken projected volumes“**. Der häufigste Fehler ist, explizit `audience: kubernetes.default.svc` zu setzen, in der Annahme, das sei der Standardwert. Für einen kubeadm-Cluster ist das KEIN garantierter Default - wenn du eine audience setzt, die der API server über `--api-audiences` nicht akzeptiert, liefert TokenReview `authenticated: false`. Gib das Feld `audience` einfach überhaupt nicht an - das kubelet fordert dann den Standard-identifier des API server an, den der Server sicher akzeptiert. Vergiss auch nicht `automountServiceAccountToken: false` am Pod selbst - sonst fügt Kubernetes zusätzlich zu deinem projected volume noch ein gewöhnliches (legacy-artiges) token volume hinzu. Ein weiterer häufiger Fehler ist, ein zu kleines `expirationSeconds` zu wählen (zum Beispiel `300`): Die Kubernetes API verlangt für ein `serviceAccountToken` projected volume mindestens `600` Sekunden - ein kleinerer Wert wird vom API server bei `kubectl apply` als invalid abgelehnt (`must be at least 10 minutes`).
</details>

---
| **3** | **Pod ohne Kubernetes-API-token** |
| :---: | :--- |
| Was wir tun | Erstelle den ServiceAccount `no-token-sa` mit `automountServiceAccountToken: false` und den Pod `no-token` in `security-104` mit diesem ServiceAccount. Setze auch am Pod selbst explizit `automountServiceAccountToken: false`. Verwende ein beliebiges sicheres langlebiges Image, zum Beispiel `busybox:1.36` mit `sleep 3600`. Mounte kein Secret mit einem ServiceAccount-token manuell - der Pod darf überhaupt keinen API-token haben, weder über automount noch über ein explizit gemountetes legacy Secret. |
| Abnahmekriterien | Beim ServiceAccount und beim Pod ist das automount deaktiviert; der Pod verwendet `no-token-sa`; in seiner Spezifikation gibt es kein automatisch hinzugefügtes token volume des ServiceAccount und kein manuell gemountetes Secret vom Typ `kubernetes.io/service-account-token`; der Versuch, `/var/run/secrets/kubernetes.io/serviceaccount/token` im Container zu lesen, endet mit einem Fehler (Datei fehlt), wobei `kubectl exec` selbst erfolgreich ausgeführt werden muss. |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Unterschied zu Aufgabe 8: Technisch würde es reichen, automount auf einer Ebene (SA oder Pod) zu deaktivieren, aber die Aufgabe verlangt **beide** Ebenen gleichzeitig (defence in depth). Prüfe dich selbst: `kubectl get pod no-token -o jsonpath='{.spec.volumes}'` darf nichts enthalten, was an `kube-api-access-*` erinnert. Wenn das Volume trotzdem auftaucht - prüfe, dass du automount VOR dem Erstellen des Pods deaktiviert hast und nicht danach (eine Änderung am SA wirkt sich nicht auf bereits erstellte Pods aus). Ein deaktiviertes automount hindert nicht daran, manuell ein altes (legacy) `Secret` mit `type: kubernetes.io/service-account-token` über `volumes[].secret` zu mounten - wenn du das tust, hat der Pod formal kein automounted Volume, erhält aber faktisch trotzdem einen gültigen API-token. Die Aufgabe verlangt das vollständige Fehlen eines tokens und nicht nur das Fehlen von automount.
</details>

---
| **4** | **Übermäßige cluster-wide Rechte entfernen** |
| :---: | :--- |
| Was wir tun | Im Cluster wurden absichtlich die ClusterRole `legacy-operator-admin` mit wildcard-Rechten und ein ClusterRoleBinding mit demselben Namen für den ServiceAccount `legacy-operator` aus `security-104` zurückgelassen. Lösche **beide** Objekte. Ersetze den wildcard-Zugriff nicht durch eine andere breite ClusterRole. |
| Abnahmekriterien | `legacy-operator-admin` existiert weder als ClusterRole noch als ClusterRoleBinding; der ServiceAccount `legacy-operator` kann in `security-104` keine `secrets` mehr lesen. |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

Wird nur das `ClusterRoleBinding` gelöscht, ohne die `ClusterRole` zu löschen, bleibt eine gefährliche Vorlage im Cluster - jemand kann später eine neue Bindung darauf erstellen. Lösche beide Objekte. Prüfe dich mit zwei separaten Befehlen: `kubectl get clusterrole legacy-operator-admin` und `kubectl get clusterrolebinding legacy-operator-admin` - beide müssen `NotFound` zurückgeben.
</details>

---
| **5** | **Anonymous access zum API server deaktivieren** |
| :---: | :--- |
| Was wir tun | • Erstelle auf der control-plane die Datei `/etc/kubernetes/authentication-config.yaml` mit einer `AuthenticationConfiguration`, die anonymous access für alle Endpoints außer `/livez`, `/readyz` und `/healthz` deaktiviert - `/livez` und `/readyz` verwendet kubeadm für die HTTPS liveness/readiness/startup probes des static Pods des API server (`/healthz` bleibt aus Kompatibilitätsgründen erhalten), und ein vollständiges `--anonymous-auth=false` lässt die probes selbst fehlschlagen und blockiert nicht nur den Zugriff des Angreifers.<br/>• Binde die Datei über ein `hostPath` volume und das Argument `--authentication-config=<Pfad-im-Container>` in `/etc/kubernetes/manifests/kube-apiserver.yaml` ein und **entferne** das vorhandene `--anonymous-auth=true` - beide Wege, anonymous access zu konfigurieren, schließen sich gegenseitig aus, und kube-apiserver startet nicht, wenn beide gesetzt sind. Das kubelet startet den static Pod automatisch neu.<br/>• Warte auf die Bereitschaft des API server (der Pod bleibt Running/Ready) und stelle sicher, dass eine nicht authentifizierte Anfrage an `/version` `401` erhält und an `/livez` und `/readyz` - `200`.<br/>• Prüfe zusätzlich, dass das effective `--authorization-mode` `Node,RBAC` enthält und **nicht** `AlwaysAllow` enthält (authentication ohne einschränkende Autorisierung ist sinnlos).<br/>• Auditiere ClusterRoleBinding, deren subjects `system:anonymous`/die Gruppe `system:unauthenticated` sind: Im Cluster wurde absichtlich eine solche gefährliche (lab-owned) Bindung zurückgelassen, `lab104-unintended-anonymous-access`, lösche sie zusammen mit ihrer ClusterRole. **Fasse nicht** die reguläre kubeadm-Bindung `system:public-info-viewer` an - sie ist ebenfalls an `system:unauthenticated` gebunden, gibt aber nur Zugriff auf die non-resource URLs `/livez`, `/readyz`, `/healthz`, `/version`, `/version/`, das ist ein normaler Teil des bootstrap (default Kubernetes RBAC) und kein Befund für diese Aufgabe.<br/>• Das ist eine eigene Schicht, getrennt von der `AuthenticationConfiguration` derselben Aufgabe: `anonymous.conditions` erlaubt dort absichtlich die anonyme identity nur auf `/livez`/`/readyz`/`/healthz` - `/version` ist anonym gerade deshalb nicht erreichbar, weil die Anfrage dorthin in der Phase authentication überhaupt keine anonymous identity erhält und es bis zur Autorisierung über `system:public-info-viewer` gar nicht kommt, selbst mit dieser breiteren Liste von non-resource URLs. |
| Abnahmekriterien | • Der static Pod des API server verwendet `--authentication-config`, das auf eine `AuthenticationConfiguration` mit `anonymous.enabled: true` und `conditions` verweist, die genau `/livez`, `/readyz`, `/healthz` enthalten.<br/>• Das Argument `--anonymous-auth` fehlt.<br/>• Der kube-apiserver Pod bleibt nach dem Neustart `Running`/`Ready`.<br/>• Ein nicht authentifiziertes `GET /version` liefert `401`.<br/>• Nicht authentifizierte `GET /livez` und `GET /readyz` liefern `200`.<br/>• Eine authentifizierte Anfrage an `/readyz` (mit gültigen credentials) funktioniert ebenfalls.<br/>• Das effective `--authorization-mode` enthält `Node,RBAC` und nicht `AlwaysAllow`.<br/>• ClusterRole/ClusterRoleBinding `lab104-anonymous-debug-access`/`lab104-unintended-anonymous-access` sind gelöscht.<br/>• Das reguläre `system:public-info-viewer` bleibt unangetastet.<br/>• Die Gruppe `system:unauthenticated` kann in keinem Namespace `pods`/`secrets`/`configmaps` lesen. |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

Bearbeite das Pod-Objekt nicht per `kubectl edit pod` - das kubelet überwacht die Manifest-Datei und setzt jede über die API vorgenommene Änderung wieder auf den ursprünglichen Zustand zurück. Bearbeite ausschließlich die Datei `/etc/kubernetes/manifests/kube-apiserver.yaml` auf der Platte des Nodes. Warte nach dem Speichern: Das kubelet erkennt die Änderung der Datei nicht sofort, und der API server ist während des Neustarts des static Pods einige Sekunden nicht verfügbar - keine Panik, wenn `curl` direkt nach dem Speichern der Datei nichts zurückgibt.

Ein einfaches `--anonymous-auth=false` ist hier **nicht geeignet**: kubeadm `release-1.36` erzeugt den static Pod des kube-apiserver mit HTTPS liveness/readiness/startup probes genau auf `/livez` und `/readyz`, und HTTP probes des kubelet übergeben keine client credentials - bei vollständiger Deaktivierung von anonymous access erhalten diese Anfragen `401`, das kubelet hält den Container für ungesund und kann den kube-apiserver in einer Schleife neu starten, was nicht nur diese Aufgabe, sondern auch die spätere Aufgabe 9 zum Scheitern bringt. Der richtige Weg ist eine `AuthenticationConfiguration` mit `anonymous.enabled: true` und `anonymous.conditions`, die anonymous access nur auf die benötigten Health-Pfade beschränken:

```yaml
# /etc/kubernetes/authentication-config.yaml
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
jwt: []
anonymous:
  enabled: true
  conditions:
  - path: /livez
  - path: /readyz
  - path: /healthz
```

`--authentication-config` und `--anonymous-auth` dürfen nicht gleichzeitig gesetzt werden - kube-apiserver startet nicht, wenn beide Argumente im Manifest vorhanden sind. Stelle sicher, dass du `--anonymous-auth=true` vollständig entfernt und nicht nur den Wert durch `false` ersetzt hast.

Zum Audit anonymer ClusterRoleBinding: `kubectl get clusterrolebinding -o json | jq -r
'.items[] | select([.subjects[]? | select(.name == "system:anonymous" or .name ==
"system:unauthenticated")] | length > 0) | .metadata.name'`. Du siehst mindestens ZWEI
Bindungen - das reguläre `system:public-info-viewer` (nicht anfassen) und das lab-owned
`lab104-unintended-anonymous-access` (lösche es zusammen mit seiner ClusterRole
`lab104-anonymous-debug-access`). Unterscheiden kannst du sie am Namen der ClusterRole, auf die sie
verweisen: `kubectl get clusterrolebinding system:public-info-viewer -o
jsonpath='{.roleRef.name}'` zeigt `system:public-info-viewer` - das ist eine ClusterRole,
die auf non-resource URLs beschränkt ist und nicht auf gewöhnliche resources.
</details>

---
| **6** | **Leck eines Secrets über env in `/proc/1/environ`: Umstellung auf volume** |
| :---: | :--- |
| Was wir tun | • Der Pod `app-vulnerable` in `security-104` erhält `db-creds` über `envFrom.secretRef` - der Wert ist für jeden zugänglich, der `kubectl exec` in den Container ausführen kann (`cat /proc/1/environ`) oder logs/describe lesen kann, falls env versehentlich ausgegeben wird.<br/>• Bestätige dieses Leck: Führe `kubectl exec -n security-104 app-vulnerable -- cat /proc/1/environ` aus und speichere die Ausgabe (mit `DB_PASSWORD`) in `/var/work/tests/artifacts/6/env-leak-before.txt`.<br/>• Erstelle den Pod mit demselben Namen `app-vulnerable` neu: Entferne `envFrom`/`env` mit diesem Secret, mounte `db-creds` als volume `db-creds-vol` nach `/etc/secrets` **read-only**, mit `defaultMode: 0400`.<br/>• Bestätige das Fehlen der Variable `DB_PASSWORD` im neuen `/proc/1/environ` und speichere `stat -L -c '%a'` der gemounteten Datei in `/var/work/tests/artifacts/6/secret-file-mode.txt` (das Flag `-L` ist Pflicht - das Secret wird über eine Symlink-Kette `..data` gemountet, ohne `-L` zeigt `stat` den Modus des Symlinks selbst und nicht der echten Datei). |
| Abnahmekriterien | `env-leak-before.txt` enthält den ECHTEN Wert von `DB_PASSWORD` aus dem Secret `db-creds` (nicht nur das Wort `DB_PASSWORD`); der finale Pod `app-vulnerable` hat kein `env`/`envFrom`, das auf `db-creds` verweist, und keine zweite Möglichkeit, dasselbe Secret zu mounten; das volume `db-creds-vol` ist nach `/etc/secrets` als `readOnly: true` mit `defaultMode: 0400` (`256` dezimal) gemountet - der Checker prüft `stat -L -c %a` selbst im Container und verlangt genau `400`; `DB_PASSWORD` fehlt in `/proc/1/environ` des finalen Pods (bei erfolgreich ausgeführtem `exec` - ein fehlgeschlagener `exec` gilt nicht als Beleg); der Prozess der Anwendung kann den Wert des Secrets dabei weiterhin tatsächlich aus `/etc/secrets/DB_PASSWORD` lesen (positive control). |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

`/proc/1/environ` im Schritt zur Bestätigung des Lecks ist nicht die einzige Möglichkeit, den Wert zu sehen
(dasselbe Ergebnis liefern `kubectl exec ... -- env` oder `echo $DB_PASSWORD`, weil
die container runtime dem per exec gestarteten Prozess standardmäßig dasselbe environment gibt wie PID 1).
`/proc/1/environ` liest das environment von PID 1 direkt über `/proc` und verlässt sich nicht darauf,
was deine konkrete exec-Shell geerbt hat - das ist derselbe Kniff, der bei der
Security-Analyse tatsächlich verwendet wird, um das environment jedes Prozesses zu sehen und nicht nur des eigenen.

Ein Volume mount **nimmt demjenigen den Zugriff nicht, der bereits `kubectl exec` hat** - `cat
/etc/secrets/DB_PASSWORD` liest nach dem Fix den Wert genauso leicht, wie `cat
/proc/1/environ` ihn vor dem Fix gelesen hat, und das ist erwartet (die positive control in der Aufgabe prüft
genau das). Bei der Aufgabe geht es nicht darum, den exec-Zugriff zu schließen - das ist weder für eine Datei noch für
eine Variable möglich, wenn der Prozess das Recht hat, den Wert zu lesen. Der echte Unterschied liegt in den Leckpfaden,
die auch OHNE explizites `exec` greifen:
- Umgebungsvariablen erbt automatisch **jeder** Kindprozess (`fork()`
  kopiert das gesamte env) - eine Drittbibliothek, ein Plugin oder ein zufälliger Subprozess innerhalb der
  Anwendung erhält `DB_PASSWORD`, auch wenn der Entwickler nicht daran gedacht hat; eine Datei wird so nicht
  weitergegeben - der Kindprozess muss den Pfad ausdrücklich kennen und sie öffnen;
- crash handler und error logger geben bei einem Absturz oft das gesamte `environ` des Prozesses aus,
  und das landet automatisch in den logs; der Inhalt einer Datei gelangt von sich aus nicht in die
  logs, solange der Code ihn nicht explizit liest und loggt;
- Umgebungsvariablen haben kein Zugriffsrechtemodell - jeder Prozess im Namespace des
  Containers sieht sie; eine Datei mit `defaultMode: 0400` hat eines - sie liest nur ein Prozess mit der passenden UID.

```text
[FAIL] defaultMode für das Secret Volume ist falsch angegeben.
💡 Du hast defaultMode: 400 angegeben (dezimal 400).
   YAML unterstützt ein oktales Literal mit führender Null (0400), das Kubernetes
   als gewöhnliche Unix-Rechte interpretiert; ohne führende Null wird 400 als dezimale
   Zahl 400 gelesen und nicht als Rechte 0400 (das ist dezimal 256).
```

Das ist der häufigste Fehler dieser Aufgabe: `defaultMode` ist ein numerisches Feld mit POSIX mode bits, und
Kubernetes YAML unterstützt dafür sowohl oktale als auch dezimale Schreibweise - anders
als JSON, wo nur dezimal zulässig ist. Wenn du `defaultMode: 400` schreibst (ohne führende
Null), fasst Kubernetes das als **dezimales** 400 auf und nicht als gewohnte Unix-Rechte
`0400`. Der richtige Weg ist, entweder `defaultMode: 0400` zu schreiben (mit führender Null, YAML
erkennt ein oktales Literal) oder explizit das dezimale Äquivalent `256` anzugeben. Prüfe
dich selbst: `kubectl get pod app-vulnerable -o jsonpath='{.spec.volumes[0].secret.defaultMode}'`
muss `256` zurückgeben, und `stat -L -c '%a' /etc/secrets/DB_PASSWORD` im Container - `400`.
</details>

---
| **7** | **Audit und Widerruf versteckter RBAC-Pfade der privilege escalation (`impersonate`, `bind`, `escalate`, CSR approval)** |
| :---: | :--- |
| Was wir tun | • Die ClusterRole `build-agent-hidden-privesc` enthält kein wildcard `*` (das ist ein eigener, bereits in Aufgabe 4 beseitigter Pfad), gibt aber dem ServiceAccount `build-agent` aus `security-104` drei tatsächlich ausnutzbare Pfade der Rechteausweitung:<br/>• `impersonate` auf `users`/`groups`/`serviceaccounts` - Identitätsvortäuschung, einschließlich cluster-admin, wenn ein solcher Benutzer dem Angreifer bekannt ist.<br/>• `create`/`update`/`bind`/`escalate` auf `clusterroles` und `create`/`update` auf `clusterrolebindings` - die Basis-verbs ermöglichen es, die Objekte selbst zu erstellen/zu ändern, und `bind`/`escalate` umgehen die eingebaute RBAC-Prüfung, die es sonst verbieten würde, Rechte zu vergeben/zu binden, die weiter reichen als die eigenen (ohne die Basis-`create`/`update` genügen `bind`/`escalate` allein nicht für eine echte Eskalation).<br/>• `update` auf `certificatesigningrequests/approval` + `approve` auf den signer `kubernetes.io/kube-apiserver-client` - die Möglichkeit, eine CSR mit beliebiger identity zu genehmigen (aber diese ClusterRole selbst gibt kein `create certificatesigningrequests`: Um den Angriff bis zur Ausstellung eines Zertifikats zu führen, braucht die identity zusätzlich eine separate Möglichkeit, eine CSR zu erstellen, zum Beispiel über eine andere kompromittierte Rolle oder eine compromised automation, die bereits CSRs einreichen kann).<br/>• Finde **alle** ClusterRoleBinding, deren ClusterRole `impersonate`, `bind` oder `escalate` erlaubt (zum Beispiel über `kubectl get clusterrole -o json \| jq` nach `rules[].verbs`), und schreibe sie in `/var/work/tests/artifacts/7/dangerous-bindings-before.txt`.<br/>• Lösche das ClusterRoleBinding `build-agent-hidden-privesc` **und** die ClusterRole `build-agent-hidden-privesc` (und, falls du weitere unbeabsichtigte findest - auch diese, aber nicht die System-`system:*` ClusterRoleBinding).<br/>• Bestätige den Widerruf per `kubectl auth can-i` für ALLE gefundenen Rechte: `impersonate users`, `bind clusterroles`, `escalate clusterroles`, `update certificatesigningrequests/approval` sowie `approve` auf den signer `kubernetes.io/kube-apiserver-client` - alle müssen `no` zurückgeben. |
| Abnahmekriterien | • `dangerous-bindings-before.txt` enthält `build-agent-hidden-privesc` unter den gefundenen Einträgen als ClusterRoleBinding (und nicht den Namen der ClusterRole, falls sie nicht übereinstimmen).<br/>• Das ClusterRoleBinding **und** die ClusterRole `build-agent-hidden-privesc` existieren nach der Korrektur nicht mehr.<br/>• `build-agent` kann nicht `impersonate`, `bind`, `escalate`, `update certificatesigningrequests/approval`.<br/>• `build-agent` kann kein `approve` auf den signer `kubernetes.io/kube-apiserver-client` ausführen.<br/>• Die System-`system:*` ClusterRoleBinding wurden nicht angetastet. |

<details>
<summary>💡 Hinweis zu Aufgabe 7</summary>

CSR approval ist eine eigene Kategorie gegenüber `impersonate`/`bind`/`escalate`: Sie fällt nicht unter denselben `jq`-Filter nach `verbs`, weil sie eine separate Regel auf die Ressource `certificatesigningrequests/approval` mit dem verb `update` ist, plus `approve` auf einen konkreten `signer`. Wenn du nur nach `impersonate`/`bind`/`escalate` filterst, findest du einen Pfad, übersiehst aber die CSR - suche beide getrennt, und speichere für jeden genau den Namen des **ClusterRoleBinding** und nicht der ClusterRole, auf die es verweist (in diesem Lab stimmen die Namen überein, aber im Allgemeinen ist das nicht garantiert). Lösche keine System-`ClusterRoleBinding` mit dem Präfix `system:` - sie werden von den core-Komponenten von Kubernetes für legitimes `impersonate` benötigt (zum Beispiel `system:kube-controller-manager`).
</details>

---
| **8** | **Namespace-level baseline: `default` ServiceAccount ohne automount** |
| :---: | :--- |
| Was wir tun | • Aufgabe 3 hat automount punktuell deaktiviert, innerhalb eines konkreten Pods und seines eigenen ServiceAccount. Hier brauchst du eine Baseline auf Ebene des **Namespace**.<br/>• Erstelle den Namespace `security-104-baseline`, warte auf das Erscheinen des automatisch erstellten ServiceAccount `default` darin (die Erstellung des ServiceAccount erfolgt asynchron durch einen separaten Controller und nicht gleichzeitig mit dem Namespace selbst).<br/>• Erst dann setze `automountServiceAccountToken: false` auf diesem ServiceAccount: `kubectl patch serviceaccount default -n security-104-baseline -p '{"automountServiceAccountToken":false}'`.<br/>• Erstelle in diesem Namespace den Pod `implicit-default-sa` aus `busybox:1.36` (`sleep 3600`), **ohne** `serviceAccountName` oder `automountServiceAccountToken` explizit anzugeben - er muss implizit den `default` SA verwenden und dessen Wert erben.<br/>• Bestätige, dass in der Spezifikation des finalen Pods das Feld `automountServiceAccountToken` fehlt (und nicht gleich `false` ist), kein token volume vorhanden ist und der Versuch, die token-Datei im Container zu lesen, genau mit einem Fehler wegen fehlender Datei endet (dabei muss `kubectl exec` selbst erfolgreich ausgeführt werden). |
| Abnahmekriterien | • Der ServiceAccount `default` in `security-104-baseline` hat `automountServiceAccountToken: false`.<br/>• Der Pod `implicit-default-sa` verwendet `serviceAccountName: default` (implizit oder explizit).<br/>• In seiner Spezifikation **fehlt** das Feld `automountServiceAccountToken` (weder explizit auf `true` noch auf `false` gesetzt).<br/>• Es gibt kein automatisch hinzugefügtes `projected`/`secret` volume mit dem token des ServiceAccount und kein manuell gemountetes legacy `Secret` vom Typ `kubernetes.io/service-account-token`.<br/>• `kubectl exec ... test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token` endet erfolgreich (exit code `0`) und bestätigt das Fehlen der Datei ausdrücklich durch einen erfolgreichen exec und nicht durch einen beliebigen Fehler. |

<details>
<summary>💡 Hinweis zu Aufgabe 8</summary>

Die Reihenfolge der Operationen ist entscheidend: Wenn du den Pod erstellst, BEVOR der `patch` auf den `default` SA des Namespace angewendet wurde, erhält der Pod einen token nach dem alten (default `true`) Wert. Patche den `default` SA auch nicht SOFORT nach `kubectl create namespace` ohne Prüfung - der ServiceAccount `default` wird von einem separaten Controller erstellt und existiert in den ersten Sekundenbruchteilen nach dem Erstellen des Namespace möglicherweise noch nicht; warte auf sein Erscheinen (`kubectl get serviceaccount default -n security-104-baseline`) und patche erst dann. Die Aufgabe gibt im Pod absichtlich kein `serviceAccountName` an - das modelliert die reale Situation, in der der Entwickler den ServiceAccount einfach vergessen hat und die Baseline ihn standardmäßig schützen muss. Ein explizites `automountServiceAccountToken: false` AM Pod SELBST würde nur eine punktuelle Einstellung beweisen (wie in Aufgabe 3) - hier musst du das Feld komplett weglassen, um genau die Vererbung vom SA/Namespace zu beweisen.
</details>

---
| **9** | **Integrationsaufgabe: RBAC-Eskalation über den audit log erkennen und eingrenzen** |
| :---: | :--- |
| Was wir tun | • Diese Aufgabe verbindet RBAC (dieses Lab) mit audit-Logging (siehe [Kapitel 32](../../course/32/de.md)) - ohne audit log wäre die Tatsache einer gefährlichen RBAC-Änderung nur post-hoc über `kubectl get` sichtbar und nicht als reproduzierbare forensic evidence.<br/>• Aktiviere auf der control-plane ein minimales audit backend: Erstelle `/etc/kubernetes/audit/policy.yaml` mit einer `RequestResponse`-Regel für `apiGroups: ["rbac.authorization.k8s.io"]` und die Ressourcen `clusterroles` und `clusterrolebindings` sowie mit einer catch-all-`Metadata`-Regel als Fallback.<br/>• Füge im static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` und die notwendigen hostPath volume/volumeMount hinzu (lege die Verzeichnisse vorher an). Warte auf die Wiederherstellung der API.<br/>• Erstelle im Namen des Administrators (`cluster1-admin`) das ClusterRoleBinding `incident-simulated-escalation`, das die ClusterRole `cluster-admin` an den ServiceAccount `build-agent` aus `security-104` bindet - das ist **kein** Eskalationsversuch von `build-agent` selbst (Aufgabe 7 hat ihm die echten Pfade der Rechteausweitung bereits entzogen), sondern eine vom Administrator modellierte gefährliche RBAC-Änderung: ein reales Szenario, in dem jemand (ein menschlicher Operator, ein Skript, ein kompromittiertes CI/CD) versehentlich oder böswillig `cluster-admin` an einen ServiceAccount vergibt, und die Aufgabe des SOC/Security-Engineers ist es, genau ein solches Ereignis über den audit log zu erkennen und nicht über ständiges manuelles `kubectl get`.<br/>• Finde im audit log das Ereignis `create` für `clusterrolebindings` mit diesem Namen, `requestObject.roleRef` auf `cluster-admin` und `system:serviceaccount:security-104:build-agent` in `requestObject.subjects`, speichere das Ereignis vollständig (einschließlich `user.username` - desjenigen, der die Anfrage tatsächlich ausgelöst hat) in `/var/work/tests/artifacts/9/audit-escalation-event.json`. Das ist nicht nur „sich vergewissern, dass die audit-Regel funktioniert“ - die reale Aufgabe des SOC-Engineers besteht hier darin, den **konkreten Eintrag** als forensic evidence **zu extrahieren und zu speichern** (der Checker liest `audit.log` auf der control-plane selbst unabhängig und gleicht die `auditID` deines artifacts mit dem echten Eintrag ab - ein erfundenes, wenn auch ähnliches JSON besteht nicht).<br/>• Führe containment durch: Lösche `incident-simulated-escalation` und bestätige per `kubectl auth can-i '*' '*' -n security-104 --as=system:serviceaccount:security-104:build-agent`, dass der Zugriff widerrufen ist; speichere das resultierende `no` in `/var/work/tests/artifacts/9/containment-result.txt` (`can-i` ohne `-n`/`-A` prüft nur den aktuellen Namespace deines kubeconfig-Kontexts und nicht den gesamten Cluster - gib den Namespace explizit an). |
| Abnahmekriterien | • Das static manifest des kube-apiserver enthält `--audit-policy-file` und `--audit-log-path`, der API server ist healthy.<br/>• `/var/work/tests/artifacts/9/audit-escalation-event.json` - ein gültiges JSON audit event mit `verb: create`, `objectRef.resource: clusterrolebindings`, `objectRef.name: incident-simulated-escalation`, `requestObject.roleRef.name: cluster-admin` und dem ServiceAccount `build-agent` aus `security-104` unter `requestObject.subjects`.<br/>• Das ClusterRoleBinding `incident-simulated-escalation` existiert nach dem containment nicht mehr.<br/>• `containment-result.txt` enthält `no`. |

<details>
<summary>💡 Hinweis zu Aufgabe 9</summary>

Die `RequestResponse`-Regel für `rbac.authorization.k8s.io` muss an ERSTER Stelle der Regelliste der policy stehen - die spezifischere Regel muss dem allgemeinen `Metadata`-catch-all vorausgehen, sonst fängt das catch-all das Ereignis früher ab und du erhältst nur die `Metadata`-Ebene statt `RequestResponse` mit dem Anfragekörper. Füge `omitStages: [RequestReceived]` auf Ebene der gesamten policy hinzu - diese Stage hat noch kein `requestObject`/`responseStatus`, und das `Metadata`-catch-all gilt für überhaupt alle Anfragen des Clusters, daher wächst `audit.log` ohne `omitStages` doppelt so schnell ohne jeden zusätzlichen Nutzen für diese Aufgabe. Erstelle `incident-simulated-escalation` erst, NACHDEM der API server mit dem neuen audit backend neu gestartet ist - sonst gelangt das Ereignis einfach nicht in den log. Diese Aufgabe prüft die Erkennung einer gefährlichen RBAC-Änderung per se und nicht, dass genau `build-agent` sie ausgeführt hat - im audit log zeigt das Feld `user.username` den realen Auslöser (den Administrator) und nicht `build-agent`; `build-agent` erscheint in diesem Ereignis nur als Empfänger der Rechte (`requestObject.subjects`). `audit-escalation-event.json` muss ein **echter** Eintrag sein, kopiert aus `/var/log/kubernetes/audit/audit.log` (einschließlich seiner `auditID`) - ein manuell zusammengebautes JSON mit mehreren übereinstimmenden Zeilen besteht die Prüfung nicht, weil der self-check den log auf der control-plane selbst liest und die `auditID` abgleicht. Vergiss das containment nicht: Das Löschen des `ClusterRoleBinding` allein ist die Hälfte der Aufgabe, die andere Hälfte ist, per `kubectl auth can-i` zu beweisen, dass der Zugriff tatsächlich widerrufen ist und nicht nur das Objekt nicht mehr lesbar ist.
</details>

---
| **10** | **Ein Secret dekodieren, erstellen und mounten** |
| :---: | :--- |
| Was wir tun | • In `security-104` existiert bereits das Opaque Secret `legacy-config` mit zwei Schlüsseln: `SERVICE_USER` und `SERVICE_TOKEN`. Lies es über die API und dekodiere beide Werte aus base64.<br/>• Erstelle ein neues generic Secret `rehydrated-config` aus literal-Werten (`kubectl create secret generic ... --from-literal=...`), mit DENSELBEN Schlüsselnamen und DENSELBEN dekodierten Werten.<br/>• Erstelle den Pod `secret-workflow` aus `busybox:1.36` (`sleep 3600`), der `rehydrated-config` als **read-only** volume nach `/etc/rehydrated` mountet.<br/>• Bestätige, dass beide Dateien im Container tatsächlich lesbar sind und die erwarteten Werte enthalten. |
| Abnahmekriterien | • `rehydrated-config` existiert und seine dekodierten `SERVICE_USER`/`SERVICE_TOKEN` stimmen mit dem ursprünglichen `legacy-config` überein.<br/>• Der Pod `secret-workflow` mountet genau dieses Secret nach `/etc/rehydrated` mit `readOnly: true`.<br/>• `kubectl exec` im Container liest beide Dateien mit dem richtigen Inhalt. |

<details>
<summary>💡 Hinweis zu Aufgabe 10</summary>

`kubectl get secret legacy-config -o jsonpath='{.data.SERVICE_USER}' | base64 -d` liefert dir
den echten Wert - schreibe keinen beliebigen String in das neue Secret, der Checker
dekodiert das Original selbst erneut und vergleicht. `kubectl create secret generic rehydrated-config
--from-literal=SERVICE_USER=... --from-literal=SERVICE_TOKEN=...` kodiert die Werte
automatisch - beim Erstellen über `--from-literal` musst du nicht selbst base64-kodieren.
Vergiss nicht `readOnly: true` am volumeMount - ein gemountetes, aber beschreibbares Secret besteht das
Abnahmekriterium buchstäblich anhand des Flags nicht, auch wenn der Pod selbst korrekt arbeitet.
</details>

---
| **11** | **Eine bestehende Role reparieren und an einen SA aus einem anderen Namespace binden** |
| :---: | :--- |
| Was wir tun | • Im Namespace `rbac-a` existieren bereits der ServiceAccount `dev`, die Role `pod-role` und das RoleBinding `pod-role-binding`. Die Role erlaubt derzeit `get`, `list`, `delete` auf `pods` - `delete` ist hier überflüssig (entferne es), und `watch` fehlt, obwohl es gebraucht wird (füge es hinzu). Korrigiere genau die vorhandene Role, erstelle keine neue.<br/>• Separat existiert im Namespace `rbac-b` bereits die ConfigMap `shared-config`. Erstelle in `rbac-b` eine neue Role und ein RoleBinding, die dem ServiceAccount `dev` **aus dem Namespace `rbac-a`** Zugriff `get`/`list` (und nur diesen) auf `configmaps` in `rbac-b` geben.<br/>• Erstelle einen Pod in `rbac-a` mit `serviceAccountName: dev`. |
| Abnahmekriterien | • Die Role `pod-role` in `rbac-a` erlaubt genau `get`, `list`, `watch` auf `pods`.<br/>• `dev` kann in `rbac-a` kein `delete pods` ausführen.<br/>• `dev` kann in `rbac-b` `get`/`list configmaps`, aber nicht `delete configmaps` und kann dort keine `secrets` lesen.<br/>• In `rbac-a` existiert ein Pod, der den ServiceAccount `dev` verwendet. |

<details>
<summary>💡 Hinweis zu Aufgabe 11</summary>

Ein `RoleBinding` kann auf ein Subjekt (`ServiceAccount`) aus JEDEM anderen Namespace verweisen -
Kubernetes unterstützt das offiziell über `subjects[].namespace`. Aber das `RoleBinding` selbst
und die damit verbundenen Rechte gelten immer nur in dem Namespace, in dem ES SELBST erstellt wurde - daher
muss die neue Role+RoleBinding genau IN `rbac-b` erstellt werden und nicht in `rbac-a`. Prüfe dich selbst:
`kubectl auth can-i get configmaps -n rbac-b --as=system:serviceaccount:rbac-a:dev` muss
`yes` zurückgeben, und `kubectl auth can-i get secrets -n rbac-b --as=system:serviceaccount:rbac-a:dev` -
`no`.
</details>

---
| **12** | **Benutzer mit Client-Zertifikat über CSR + namespaced RBAC** |
| :---: | :--- |
| Was wir tun | • Erstelle einen neuen Kubernetes-Benutzer `john`, der über ein Client-Zertifikat authentifiziert wird: Erzeuge einen private key, dann eine CSR (`openssl req -new`) mit `CN=john`.<br/>• Reiche sie als Kubernetes `CertificateSigningRequest` `john-csr` mit `signerName: kubernetes.io/kube-apiserver-client` ein; genehmige die CSR (`kubectl certificate approve`).<br/>• Extrahiere das ausgestellte Zertifikat aus `status.certificate` (base64-decode) und speichere es zusammen mit dem private key in `/var/work/tests/artifacts/12/john.crt` und `.../john.key`.<br/>• Erstelle im Namespace `development` (bereits angelegt) eine Role, die `create`/`list`/`get` auf `pods` erlaubt, und ein RoleBinding auf das subject `{kind: User, name: john}`.<br/>• Baue für John eine separate kubeconfig (`kubectl config set-cluster`/`set-credentials --client-certificate/--client-key`/`set-context`) und speichere sie als `/var/work/tests/artifacts/12/john.kubeconfig`; stelle sicher, dass `kubectl --kubeconfig=/var/work/tests/artifacts/12/john.kubeconfig get pods -n development` tatsächlich funktioniert und dieselbe Anfrage in einen anderen Namespace `Forbidden` erhält - das beweist ein funktionierendes Zertifikat genauso wie eine direkte TLS-Anfrage, aber über das gewohnte `kubectl` statt `curl`.<br/>• Bestätige mit Live-Prüfungen `kubectl auth can-i --as=john`: John kann `create`/`list`/`get` pods in `development`, kann sie dort nicht `delete` und hat dieselben Rechte in einem anderen Namespace nicht. |
| Abnahmekriterien | • `john-csr` verwendet den richtigen signer und ist `Approved`.<br/>• Das ausgestellte Zertifikat hat `CN=john` und wird tatsächlich gegen die CA dieses Clusters verifiziert.<br/>• Role+RoleBinding in `development` geben John genau `create`/`list`/`get` auf `pods`.<br/>• John kann dort keine pods `delete` und hat keinen Zugriff in anderen Namespaces.<br/>• Die gespeicherten `john.crt`/`john.key` werden vom API server bei einer direkten TLS-Anfrage tatsächlich akzeptiert (und nicht nur über `--as=john` impersonation).<br/>• Die gebaute kubeconfig existiert unter dem Pfad `/var/work/tests/artifacts/12/john.kubeconfig`, und `kubectl --kubeconfig=<diese Datei> get pods -n development` funktioniert tatsächlich, während dieselbe Anfrage in einen anderen Namespace mit `Forbidden` endet. |

<details>
<summary>💡 Hinweis zu Aufgabe 12</summary>

Verwechsle diese Aufgabe nicht mit Lab 114: Dort analysierst du ein BEREITS vorhandenes Zertifikat aus der
kubeconfig, während hier eine vollständig neue, tatsächlich funktionierende identity von Grund auf ausgestellt werden muss.
RBAC für einen zertifikatsbasierten Benutzer wird über `subjects: [{kind: User, name:
john}]` gebunden und nicht über einen `ServiceAccount` - ein `User` hat in Kubernetes kein eigenes API-Objekt, seine
„Existenz“ wird vollständig dadurch bestimmt, dass der CN im Client-Zertifikat mit dem
`name` im binding übereinstimmt. `--as=john` in `kubectl auth can-i` prüft nur die RBAC-Logik
(impersonation), beweist aber nicht, dass das Zertifikat wirklich gültig ist - vergewissere dich separat,
dass `openssl verify` gegen `/etc/kubernetes/pki/ca.crt` auf der control-plane `OK` zurückgibt.
</details>

## Prüfung

Führe auf der Arbeitsmaschine aus:

```bash
check_result
```

Die Prüfung enthält Init und zwölf unabhängige Aufgaben. Nach der Änderung des API server
können einige Tests kurz auf den Neustart des static Pods warten.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD)

## Löschen

```bash
TASK=104 make delete_cks_task
```
