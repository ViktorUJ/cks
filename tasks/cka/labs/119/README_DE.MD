[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 119 — Speed-Drills und JSONPath

## Beschreibung

Ein Geschwindigkeitstrainer für CKA/CKAD: kurze, gleichartige Aufgaben zum imperativen
Erstellen von Objekten (Pod, Deployment, Service, ConfigMap, Secret) und ein separater Block
zu `-o jsonpath` — das Extrahieren von Daten aus Cluster-Objekten in Dateien.

Die Aufgaben sind im Prüfungsstil formuliert und werden automatisch mit dem Befehl
`check_result` überprüft. Ziel des Drills ist nicht die Theorie, sondern Geschwindigkeit und
Muskelgedächtnis: Routine bei imperativen Befehlen aufbauen und das Prüfungstempo halten
(~6-8 Minuten pro Aufgabe). Die Antwortdateien der JSONPath-Aufgaben werden in
`/home/ubuntu/answers/` gespeichert.

## Ziel

Den Stoff der Kurskapitel festigen:

- [Kapitel 3. Arbeiten mit kubectl: imperativer und deklarativer Ansatz](../../course/03/ru.md) — schnelle imperative Befehle, `--dry-run=client -o yaml`, Objektgeneratoren
- [Kapitel 47. CKAD-Prüfung: JSONPath und kubectl-Produktivität](../../course/47/ru.md) — Datenextraktion via `-o jsonpath`, custom-columns, `--sort-by`
- [Kapitel 48. CKA-Prüfung: Zeitmanagement und Strategie](../../course/48/ru.md) — Zeiteinteilung und Reihenfolge der Aufgaben

## Was wir tun und warum

| Block | Aufgaben | Fähigkeit |
|-------|----------|-----------|
| **Drills** | Namespace, Deployment, Service, ConfigMap, Secret | Geschwindigkeit imperativer Befehle, `--dry-run` (Kapitel 3) |
| **JSONPath** | Node-Versionen, Pod-Images, ClusterIP des Service → in Dateien | `-o jsonpath`, Datenextraktion unter Zeitdruck (Kapitel 47) |

## Infrastruktur

Die Umgebung wird in AWS (`eu-central-1`) via Terragrunt bereitgestellt und besteht aus:

| Komponente | Beschreibung                                                          |
|------------|-----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` mit öffentlichen Subnetzen                         |
| `ssh-keys` | SSH-Schlüssel für den Zugriff auf die Nodes                            |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, Single-Node |
| `worker`   | Arbeitsmaschine mit `kubectl` und `check_result`                       |

Instanzen: `t3.medium` (master), Ubuntu `22.04`. Der Cluster ist Single-Node — beim Master
ist der Taint `control-plane` entfernt, daher werden Pods direkt auf ihm eingeplant.

## Bereitstellung

```bash
TASK=119 make run_cka_task
```

Verbinde dich nach der Erstellung per SSH mit der Arbeitsmaschine (worker) und löse die
Aufgaben von dort. `kubectl` ist bereits auf den Kontext `cluster1-admin@cluster1`
eingestellt.

Nützliche Befehle auf der Arbeitsmaschine:

```bash
time_left       # wie viel Zeit bleibt
check_result    # Lösung prüfen
```

## Aufgaben

---
|        **1**        | **Namespace**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle den Namespace `drill` — in ihm werden die Objekte der übrigen Aufgaben leben (`kubectl create namespace drill`). |
| Abnahmekriterien    | - Namespace `drill` existiert. |
---
|        **2**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle im Namespace `drill` ein Deployment `api` mit dem Image `viktoruj/ping_pong:latest` und 3 Replicas (`kubectl -n drill create deployment api --image=viktoruj/ping_pong:latest --replicas=3`). |
| Abnahmekriterien    | - Deployment `api` in `drill`: 3 bereite Replicas. |
---
|        **3**        | **Service**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Veröffentliche das Deployment `api` als Service vom Typ ClusterIP mit dem Namen `api-svc` auf Port 80 (`kubectl -n drill expose deployment api --name=api-svc --port=80 --target-port=8080`). |
| Abnahmekriterien    | - Service `api-svc` (ns `drill`): Endpoints sind nicht leer. |
---
|        **4**        | **ConfigMap und Secret**                                    |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle im Namespace `drill` eine ConfigMap `cfg` mit dem Key `APP_COLOR=blue` und ein Secret `sec` mit dem Key `PASSWORD` (Wert beliebig). Verwende `--from-literal`. |
| Abnahmekriterien    | - `cfg.data.APP_COLOR=blue`;<br/>- das Secret `sec` hat den Key `PASSWORD`. |
---
|        **5**        | **JSONPath: Node-Versionen**                                |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Extrahiere die `kubeletVersion` aller Nodes via `-o jsonpath` und speichere das Ergebnis in der Datei `/home/ubuntu/answers/versions.txt` (Pfad `{.items[*].status.nodeInfo.kubeletVersion}`). |
| Abnahmekriterien    | - Der Inhalt von `versions.txt` stimmt mit der `jsonpath`-Ausgabe für die Nodes überein. |
---
|        **6**        | **JSONPath: Pod-Images**                                    |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Extrahiere die Container-Images aller Pods im Namespace `drill` via `-o jsonpath` und speichere sie in `/home/ubuntu/answers/images.txt` (Pfad `{.items[*].spec.containers[*].image}`). |
| Abnahmekriterien    | - Die Menge der Images in `images.txt` stimmt mit der `jsonpath`-Ausgabe für die Pods in `drill` überein. |
---
|        **7**        | **JSONPath: ClusterIP des Service**                         |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Extrahiere die ClusterIP des Service `api-svc` via `-o jsonpath` und speichere sie in `/home/ubuntu/answers/api-ip.txt` (Pfad `{.spec.clusterIP}`). |
| Abnahmekriterien    | - Der Wert in `api-ip.txt` stimmt mit `.spec.clusterIP` des Service `api-svc` überein. |
---

## Ergebnisprüfung

Starte auf der Arbeitsmaschine die automatische Prüfung:

```bash
check_result
```

Das Skript führt die Tests aus und zeigt, wie viele Aufgaben erledigt sind.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD)

## Abdeckung der Mock-Prüfungen

Grundlegende Fähigkeiten in Geschwindigkeit und JSONPath, die in allen CKA- und
CKAD-Mock-Prüfungen gefragt sind.

## Löschen von Cluster und Ressourcen

```bash
TASK=119 make delete_cka_task
```
