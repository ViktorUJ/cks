[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 - Kubeconfig contexts, client certificates und API exposure

## Beschreibung

Das kubeconfig, das dem Studenten ausgegeben wird, enthält mehrere contexts: den funktionierenden `cluster1-admin@cluster1`
und zwei bewusst nicht funktionierende (`staging-admin@staging`, `legacy-admin@legacy`), die auf nicht existierende
API server zeigen. `current-context` ist direkt nach dem Login auf den nicht funktionierenden `staging-admin@staging` gesetzt - das
bildet absichtlich eine reale Situation aus der Prüfung nach, in der dem Kandidaten ein kubeconfig mit mehreren
contexts gegeben wird und er selbst herausfinden muss, welcher davon funktioniert.

Separat gibt es im selben kubeconfig den Benutzer `cluster9-admin` mit einem vollwertigen, tatsächlich generierten
selbstsignierten client certificate (`client-certificate-data`/`client-key-data`). Dieses Zertifikat gibt keinerlei
Rechte im Cluster (sein CA wird vom apiserver nicht als vertrauenswürdig angesehen) - die Aufgabe lehrt, ein
client certificate aus dem kubeconfig zu lesen und zu analysieren, und nicht, sich damit zu authentifizieren.

Außerdem deckt die Lab das klassische Szenario der Verkleinerung der Angriffsfläche eines Service ab: Zuerst
erstellst du bewusst einen `NodePort` Service (von außen erreichbar über die IP des control-plane-Nodes), dann reduzierst du ihn auf
`ClusterIP` und belegst die Wirkung live in beide Richtungen.

## Bereitstellung

Starte auf der Verwaltungsmaschine die Umgebung:

```bash
TASK=114 make run_cks_task
```

Nach erfolgreicher Bereitstellung gibt Terraform den SSH-Befehl für die Verbindung zum worker aus:

```
worker_pc_ssh = "ssh ubuntu@<IP> password=<PASSWORD>"
```

Verbinde dich nur über die Adresse aus der Terraform-Ausgabe:

```bash
ssh ubuntu@<IP>
```

Arbeite auf dem worker. Prüfe jede Etappe selbstständig; starte `check_result` nach der Erledigung der
Aufgaben, öffne die Referenzlösung erst nach einem eigenen Versuch oder bei Schwierigkeiten.

## Ziel

Lernen, sicher mit einem kubeconfig zu arbeiten, das mehrere Kontexte enthält, ein
client certificate zu extrahieren und zu prüfen, ohne es zur Authentifizierung zu verwenden, und die exposure eines Service
durch das Umschalten `NodePort` -> `ClusterIP` bewusst zu steuern.

## Infrastruktur

| Komponente | Zweck |
| --- | --- |
| kubeconfig (`~/.kube/config`) | 4 context: 1 funktionierender (`cluster1-admin@cluster1`), 2 decoy (`staging-admin@staging`, `legacy-admin@legacy`), 1 mit echtem client certificate (`cluster9-admin@cluster1`) |
| `cks-114` | Namespace deiner backend-Anwendung und des Service |
| control-plane EC2 | Ein-Node-kubeadm-Cluster, CNI Calico |

## Aufgaben

---

| **1** | **Kubeconfig context inventory** |
| :---: | :--- |
| Was wir tun | • Führe `kubectl config get-contexts` aus und bestimme den aktuellen (nicht funktionierenden) `current-context`.<br/>• Finde den tatsächlich funktionierenden context und wechsle darauf: `kubectl config use-context <name>`. |
| Abnahmekriterien | • `current-context` == `cluster1-admin@cluster1`.<br/>• Aus diesem context geht tatsächlich eine Anfrage an den API server durch (er existiert nicht nur in der Datei). |
| Prüfung | `kubectl config current-context`, dann `kubectl get nodes` - muss eine echte Liste der Nodes zurückgeben und keinen connection error. |

---

| **2** | **Client certificate extraction** |
| :---: | :--- |
| Was wir tun | • Extrahiere `client-certificate-data` des Benutzers `cluster9-admin` aus dem kubeconfig, dekodiere base64 und analysiere das Zertifikat mit `openssl x509`.<br/>• Speichere das Ergebnis in `/var/work/tests/artifacts/task2-cert.txt` im Format `KEY=VALUE`, ein Wert pro Zeile: `SHA256_FP`, `SUBJECT`, `ISSUER`, `NOTBEFORE`, `NOTAFTER`. |
| Abnahmekriterien | • Alle fünf Werte im artifact stimmen mit dem überein, was aus dem ursprünglichen bootstrap-Zertifikat `cluster9-admin` extrahiert wird.<br/>• Der Checker gleicht den ursprünglichen fingerprint, die Unveränderlichkeit des Zertifikats im kubeconfig und alle fünf Felder ab. |
| Prüfung | ```bash<br/>cert=$(kubectl config view --raw -o jsonpath='{.users[?(@.name=="cluster9-admin")].user.client-certificate-data}' \| base64 -d)<br/>echo "$cert" \| openssl x509 -noout -fingerprint -sha256 -subject -issuer -startdate -enddate<br/>```<br/>`-fingerprint -sha256` gibt `sha256 Fingerprint=AA:BB:...` aus - schreibe ins artifact den hex ohne Doppelpunkte (Groß-/Kleinschreibung ist egal). |

---

| **3** | **Baseline: NodePort exposure** |
| :---: | :--- |
| Was wir tun | • Erstelle den Namespace `cks-114`.<br/>• Erstelle das Deployment `backend` (zum Beispiel `viktoruj/ping_pong:alpine` mit `SRV_PORT=80`, label `app=backend`).<br/>• Erstelle den Service `kubernetes-public` vom Typ `NodePort` auf Port 80, mit explizitem `nodePort: 30114`.<br/>• **Fasse** den Service `default/kubernetes` **nicht an**. |
| Abnahmekriterien | • Das Backend ist tatsächlich erreichbar, sowohl vom Node selbst über `<node-internal-ip>:30114` als auch innerhalb des Clusters über `kubernetes-public.cks-114.svc.cluster.local`.<br/>• `default/kubernetes` bleibt `ClusterIP`.<br/>• Aufgabe 4 macht denselben Service anschließend zu `ClusterIP`, daher ist der NodePort-Zustand zum Ende der Lab nicht mehr zu beobachten: Die historische NodePort-Phase wird durch zwei HTTP 200 Proben (vom worker und per DNS aus einem Pod), die Prüfung von Backend/EndpointSlice und einen Monitor bestätigt, der die UID von Service und Deployment speichert.<br/>• Führe zuerst Aufgabe 3 vollständig aus und warte auf die Datei `/var/lib/cks-lab114-checker/nodeport-phase-seen`, die der Monitor nach beiden erfolgreichen live-Proben erstellt; erst danach führe Aufgabe 4 aus. Die Datei ist die Bestätigung der historischen Phase für denselben Service/dasselbe Deployment. |
| Prüfung | Vom worker (außerhalb des Clusters): `curl http://<node-internal-ip>:30114/` -> HTTP 200.<br/>Aus dem Cluster (temporärer Pod mit curl): `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200. IP des Nodes: `kubectl get nodes -o wide`. |

---

| **4** | **Reduce exposure: NodePort -> ClusterIP** |
| :---: | :--- |
| Was wir tun | • Ändere `kubernetes-public` auf den Typ `ClusterIP`.<br/>• Denke daran: Der API server erlaubt es nicht, `nodePort` beim Typ `ClusterIP` zu belassen - das Feld muss explizit entfernt werden (`kubectl edit svc kubernetes-public` und lösche die Zeile `nodePort`, oder `kubectl patch` mit `$patch: replace` auf dem Array `ports`). |
| Abnahmekriterien | • Der externe Pfad `<node-internal-ip>:30114` ist jetzt auf Transportebene blockiert (connection refused/timeout).<br/>• Der clusterinterne Pfad funktioniert weiterhin.<br/>• Der backend Pod bleibt Ready. |
| Prüfung | Vom worker: `curl -m5 http://<node-internal-ip>:30114/` -> Verbindungsfehler (kein HTTP-Code).<br/>Aus dem Cluster: `curl http://kubernetes-public.cks-114.svc.cluster.local/` -> HTTP 200 wie zuvor.<br/>`kubectl -n cks-114 get svc kubernetes-public -o yaml` -> `type: ClusterIP`, bei keinem Port gibt es `nodePort`. |

## Prüfung

```bash
check_result
```

Der Checker prüft `current-context` und eine Live-Anfrage an die API darüber, extrahiert und analysiert unabhängig das
Zertifikat `cluster9-admin`, prüft es gegen den ursprünglichen bootstrap fingerprint und vergleicht es mit deinem artifact, und führt außerdem eine externe und eine clusterinterne HTTP 200 probe aus, prüft Deployment, EndpointSlice und die Unveränderlichkeit von `default/kubernetes`. Die historische NodePort-Phase bestätigt ein root-owned Monitor mit zwei live-Proben vor dem Umschalten des Service; im Zustand ClusterIP prüft der Checker live DNS und die transportseitige Ablehnung von NodePort.

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=114 make delete_cks_task
```
