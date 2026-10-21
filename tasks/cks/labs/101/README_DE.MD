[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 101 - NetworkPolicy: default-deny, Isolation und EC2 IMDS

## Beschreibung

`NetworkPolicy` funktioniert wie eine Allow-list: Nach einem default-deny werden die benötigten Flows nur durch explizite Regeln wieder erlaubt. Die Durchsetzung der Regeln übernimmt Calico. Der Worker dieser Übung ist eine von Terraform verwaltete EC2-Instanz; ihr Instance Metadata Service (IMDS) ist unter `http://169.254.169.254/` erreichbar. Terraform aktiviert den HTTP-Endpoint explizit, lässt IMDSv1 GET für einen sicheren Probe zu und setzt das response hop limit auf `2`, damit ein gewöhnlicher Pod vor dem default-deny die Netzwerkerreichbarkeit von IMDS bestätigen kann.

Die Übung prüft nur die Netzwerkerreichbarkeit des IMDS-Endpoints, ohne Metadata oder Credentials zu lesen. Jeder tatsächlich erhaltene HTTP-Status `1xx–5xx` bedeutet, dass ein TCP/HTTP-Pfad zum IMDS existiert. Der Code `000` (`HTTP:000` in den Lösungsbefehlen, `HTTPCODE:000` in der checker-Ausgabe) zusammen mit einem Transport-Error/Timeout bedeutet, dass keine HTTP-Antwort vorliegt. Der konkrete HTTP-Status hängt von den EC2 metadata options ab: Ist token usage `required`, erhält ein GET ohne gültigen IMDSv2-Token `401`; ist IMDSv1 erlaubt, gilt ein GET ohne Token als IMDSv1-Anfrage und kann eine normale HTTP-Antwort erhalten.

**Restrisiko.** Am Worker-EC2 ist ein IAM instance profile angehängt, und ein IMDSv1 GET ohne Token auf `latest/meta-data/iam/security-credentials/<role>` liefert tatsächlich temporäre AWS-Credentials (AccessKeyId/SecretAccessKey/SessionToken) - das ist kein hypothetisches Risiko, sondern das tatsächliche Verhalten der aktuellen Umgebung. Die Rolle selbst ist auf nahezu null Rechte beschränkt (least privilege: sie kann nicht einmal ihre eigene IAM-Rolle über `iam:GetRole` lesen), der praktische Wert eines Lecks für einen Angreifer ist daher minimal, aber du musst klar verstehen: In production würde derselbe Befehl bei derselben Konfiguration (`HttpTokens=optional`, IMDSv1 erlaubt) echte Credentials der Produktionsrolle mit echten Rechten liefern. Das Lab reproduziert dieses Anti-Pattern aus Kapitel 02.1 (IMDSv1 erlaubt, response hop limit `2`) absichtlich für den Probe und um zu üben, diese Schwachstelle über NetworkPolicy zu finden; in production verwende `HttpTokens=required` (nur IMDSv2) und `HttpPutResponseHopLimit=1`.

## Bereitstellung

Starte auf der Verwaltungsmaschine die Umgebung:

```bash
TASK=101 make run_cks_task
```

Nach erfolgreicher Bereitstellung gibt Terraform den SSH-Befehl zur Verbindung mit dem Worker aus. Er hat das Format:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Zum Beispiel:

```
18:53:06.019 STDOUT [worker] terraform: worker_pc_ssh = "ssh ubuntu@18.193.110.150 password= fq0J9RuZWN"
```

Verwende zur Verbindung nur die Adresse aus dem Befehl:

```bash
ssh ubuntu@<IP>
```

Wenn SSH nach dem Passwort fragt, gib den Wert ein, den Terraform nach `password=` angezeigt hat.

**Für Runtime-Prüfungen** verwende einen temporären Diagnose-Pod mit denselben Labels wie die zu prüfende Identity. Für HTTP-Prüfungen wird ein Image mit curl benötigt (`curlimages/curl:8.11.1`); für DNS ein Image mit nslookup (`busybox:1.36.1`). Lösche nach der Prüfung die temporären Pods und temporären Policies.

Arbeite auf dem Worker. Stelle vor dem Start sicher, dass die Namespaces sauber sind (zur Sicherheit):

```bash
kubectl delete namespace cks-101 cks-101-legacy imds-control --ignore-not-found --wait=true
printf 'EC2 IMDS target: %s\n' 'http://169.254.169.254/'
time_left
```

Prüfe jede Phase selbstständig an deinen Ressourcen; starte `check_result` erst nach Erledigung der Aufgaben, und öffne die Referenzlösung erst nach einem eigenen Versuch oder bei Schwierigkeiten.

## Ziel

Eine minimale Ingress/Egress-Allow-list konfigurieren, den Image digest festnageln, die AND-Selector-Semantik und das exakte `ipBlock.except` für IMDS nachweisen und anschließend einen gewöhnlichen Pod mit `hostNetwork` vergleichen, ohne vorab ein universelles Ergebnis anzunehmen.

## Infrastruktur

| Komponente | Zweck                                                                                 |
| ------------------ | ---------------------------------------------------------------------------------------------------- |
| `cks-101`        | Namespace der Anwendung und deiner `NetworkPolicy`                                        |
| `cks-101-legacy` | Namespace des Legacy-Client-Szenarios                                                     |
| `imds-control`   | unabhängiger Namespace ohne Policy für Baseline und wiederholten Control-Probe |
| Worker-EC2       | von Terraform verwaltete EC2-Instanz mit IMDS `http://169.254.169.254/` |
| CNI                | Calico                                                                                               |

## Aufgaben

---

|           **1**           | **Anwendung**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
|       Was wir tun       | Namespace `cks-101`; Deployments `frontend` und `backend` mit `replicas: 1`, ohne `hostNetwork`, mit identischem `viktoruj/ping_pong@sha256:<64hex>`; Service `backend` TCP/8080.<br/><br/>**So erhältst du den aktuellen digest:**<br/>1. Starte vorübergehend einen Pod mit dem Image `viktoruj/ping_pong:latest`.<br/>2. Warte auf pull und Ready.<br/>3. Führe `digest=$(kubectl get pod <pod_name> -o yaml \| grep imageID \| cut -d'@' -f2)` aus und erhalte `sha256:<64hex>`.<br/>4. Lösche den temporären Pod.<br/>5. Verwende den erhaltenen digest für beide Deployments: `viktoruj/ping_pong@sha256:<64hex>`. |
| Abnahmekriterien | Beide Replicas sind Ready, die image references sind identisch, der Service hat einen Endpoint.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|        Prüfung        | Führe `kubectl -n cks-101 get deploy,svc,endpoints` aus und stelle sicher, dass:<br/>1. Beide Deployments `1/1 Ready` haben.<br/>2. Der Service `backend` einen Endpoint hat.<br/><br/>Zur Prüfung des pinned image führe aus:<br/>`kubectl -n cks-101 get deploy frontend backend -o yaml \| grep 'image:'`<br/>Beide Deployments müssen dasselbe Image der Form `viktoruj/ping_pong@sha256:<64hex>` verwenden. |

---

|           **2**           | **Baseline, default-deny und wiederholter Probe**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| :-----------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Was wir tun       | Erstelle den Namespace `imds-control` und einen temporären curl-Pod. Erstelle den frontend-Probe in `cks-101`. **Vor `default-deny`** bestätige zwei Baselines: frontend → backend und frontend → IMDS sind erreichbar; `imds-control` → IMDS ist ebenfalls erreichbar. Erstelle dann `default-deny`. **Nach `default-deny`** wiederhole die IMDS-Probes: frontend muss `HTTP 000` und curl `7`/`28` erhalten, und `imds-control` muss weiterhin eine echte HTTP-Antwort `1xx–5xx` mit exit `0` erhalten. Der Backend-deny wird in Task 3 nach der Wiederherstellung von DNS geprüft. |
| Abnahmekriterien | Vor dem deny sind backend und IMDS tatsächlich erreichbar. Nach dem deny hat frontend → IMDS `HTTP 000` + curl `7`/`28`; das unabhängige `imds-control` behält HTTP `1xx–5xx` + exit `0`. |
|        Prüfung        | 1. Vor `default-deny`: curl aus dem frontend-Probe an `http://backend:8080/` muss eine HTTP-Antwort + exit `0` erhalten.<br/>2. Vor `default-deny`: frontend und `imds-control` müssen eine echte HTTP-Antwort vom IMDS erhalten.<br/>3. Prüfe `default-deny`: leerer `podSelector`, `Ingress` + `Egress`, keine allow-rules.<br/>4. Nach `default-deny`: frontend → IMDS muss `HTTP 000` + curl `7`/`28` liefern; `imds-control` → IMDS muss weiterhin HTTP `1xx–5xx` + exit `0` erhalten.<br/>5. Prüfe den Backend-deny nicht vor der Wiederherstellung von DNS - er wird in Task 3 geprüft. |

---

|           **3**           | **DNS**                                                                                                                                                                                                                                                                                                                                                                                                                 |
| :-----------------------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Was wir tun       | Gib dem frontend nach `default-deny` mit der ersten allow-rule nur den Zugriff auf `kube-system/kube-dns` über exakt UDP/53 und TCP/53 zurück, ohne `endPort`. Erstelle für die Prüfung einen separaten `dns-probe` auf `busybox:1.36.1` mit dem Label `app=frontend`. |
| Abnahmekriterien | Das DNS-allow-set ist genau UDP/53 + TCP/53; `nslookup kubernetes.default.svc.cluster.local` funktioniert. Das Backend darf in diesem Moment noch nicht über TCP/8080 erreichbar sein. |
|        Prüfung        | 1. Prüfe `allow-frontend-dns` im YAML: nur UDP/53 und TCP/53, ohne `endPort` und zusätzliche Ports.<br/>2. Führe `nslookup kubernetes.default.svc.cluster.local` aus dem `dns-probe` aus.<br/>3. Führe nach erfolgreichem DNS curl aus dem frontend-Probe an `http://backend:8080/` aus: Vor Task 4 wird `HTTP 000` + curl `7`/`28` erwartet. |

---

|           **4**           | **NetworkPolicy für die Anwendung**                                                                                                                                                                         |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Was wir tun       | Erstelle `allow-frontend-egress-to-backend` und `allow-backend-ingress-from-frontend`. Danach muss frontend eine echte HTTP-Antwort von `http://backend:8080/` erhalten. |
| Abnahmekriterien | frontend → backend:8080 ist erlaubt; die foreign identity bleibt blockiert.                                                                                                                |
|        Prüfung        | Positive: frontend curl über Service-DNS. Negative: Ein foreign Pod mit temporärer egress policy zum Backend darf den Backend-ingress nicht passieren.                                                              |

---

|           **5**           | **Abschließende IMDS-Prüfung**                                                                                                                                                                                                                                                                                                                   |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Was wir tun       | Wiederhole nach dem Hinzufügen der DNS- und Application-allow-policies denselben IMDS-Probe aus dem frontend-Pod und aus dem unabhängigen `imds-control`. Ziel ist der Nachweis, dass die neuen allow-policies IMDS nicht geöffnet haben. Hilfs-artifact-Dateien müssen nicht erstellt werden. |
| Abnahmekriterien | `imds-control`: echter HTTP-Status `1xx–5xx` + exit `0`; frontend: `HTTP 000` + curl `7`/`28`.                                                                                                                                                                                                                                      |
|        Prüfung        | Führe denselben bounded curl (`-m 5`) aus beiden Pods aus und vergleiche das tatsächliche Ergebnis. Verwende nicht `curl -f`: HTTP `401/403/404/...` bedeutet trotzdem Netzwerkerreichbarkeit.                                                 |

---

|           **6**           | **Legacy AND und IMDS except**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| :-----------------------------: | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Was wir tun       | Erstelle den Namespace `cks-101-legacy` mit dem Deployment `legacy-client`: replicas=1, ohne hostNetwork, Image `curlimages/curl:8.11.1`, Befehl `sleep 3600`. Erstelle die NetworkPolicy `allow-backend-ingress-from-legacy` im Namespace `cks-101`: wählt backend aus, enthält einen ingress peer mit AND selector (namespaceSelector und podSelector in einem Element `from`), TCP/8080. Erstelle die NetworkPolicy `allow-legacy-egress` im Namespace `cks-101-legacy`: wählt app=legacy-client aus, enthält ipBlock cidr=0.0.0.0/0 mit dem einzigen except 169.254.169.254/32, ohne zusätzliche allow-rules. Prüfe: 1) IMDS aus legacy-client ist blockiert; 2) legacy-client kann das Backend erreichen; 3) ein Pod mit anderem Label im selben Namespace kann den ingress nicht passieren; 4) ein Pod mit label=legacy-client im Namespace cks-101 kann den ingress nicht passieren. Lösche nach den Prüfungen die temporären Pods und temporären Policies. |
| Abnahmekriterien | IMDS ist blockiert, der tatsächliche Datenfluss legacy-client → backend ist erlaubt, ein Pod mit falschem Label oder aus dem falschen Namespace ist blockiert.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|        Prüfung        | 1. Führe `kubectl -n cks-101-legacy get networkpolicy allow-legacy-egress -o yaml` aus - stelle sicher, dass `ipBlock.cidr=0.0.0.0/0` ist und das einzige `except` gleich `169.254.169.254/32` ist.<br/>2. Führe `kubectl -n cks-101 get networkpolicy allow-backend-ingress-from-legacy -o yaml` aus - stelle sicher, dass `namespaceSelector` und `podSelector` in einem Element `from` stehen, Port TCP/8080.<br/>3. Curl aus `legacy-client` an IMDS muss `HTTP 000` und exit `7` oder `28` liefern.<br/>4. Curl aus `legacy-client` an das Backend muss eine echte HTTP-Antwort erhalten.<br/>5. Ein Pod mit anderem Label in `cks-101-legacy` mit temporärem egress zum Backend darf den Backend-ingress nicht passieren.<br/>6. Ein Pod mit `app=legacy-client` im Namespace `cks-101` mit temporärem egress zum Backend darf den Backend-ingress ebenfalls nicht passieren. |

---

|           **7**           | **Beobachtung von hostNetwork**                                                                                                                                                                                                                                                                                                                                                                                        |
| :-----------------------------: | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
|       Was wir tun       | Erstelle `hostnetwork-probe` mit dem Image `curlimages/curl:8.11.1`, dem Label `app=frontend` und `spec.hostNetwork=true`. Führe daraus denselben IMDS-curl aus, den du für den gewöhnlichen frontend-Pod verwendet hast. Vergleiche die tatsächliche Beobachtung mit Task 5. Hilfs-artifact-Dateien müssen nicht erstellt werden. |
| Abnahmekriterien | Pod ist Ready, `hostNetwork=true`, ein echter IMDS-Probe wurde ausgeführt. Für hostNetwork wird kein universelles erwartetes Ergebnis angenommen: Das Verhalten hängt von CNI und Node-Konfiguration ab. |
|        Prüfung        | Prüfe `hostNetwork: true`, führe dann einen bounded IMDS curl (`-m 5`) und `echo $?` aus. Vergleiche die tatsächliche Beobachtung mit dem gewöhnlichen Pod aus Task 5. |

## Prüfung

```bash
check_result
```

Der Checker erstellt und löscht seinen eigenen `imds-control`-Namespace und eigene Probes: Vor und nach dem deny in `cks-101` bestätigt er, dass das echte IMDS aus einem unabhängigen Namespace ohne Policy antwortet. Er vertraut keinen Control-Ressourcen aus einem vorherigen Versuch und ersetzt nicht deine eigenen Baseline-/Runtime-Prüfungen. Zusätzliche Policies, die die erlaubten Flows erweitern, führen zu einem Fehler.

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=101 make delete_cks_task
```
