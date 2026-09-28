[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 120 — Drills: Services und Netzwerk

## Beschreibung

Ein Geschwindigkeitstrainer für die Domäne Services & Networking. Kurze, unabhängige
Aufgaben zum Erstellen von Services (ClusterIP, NodePort, headless), Ingress und
NetworkPolicy, plus ein Block zu JSONPath.

Die Aufgaben sind im Prüfungsstil formuliert mit automatischer Prüfung über den Befehl
`check_result`. Ziel eines Drills ist nicht die Theorie, sondern Geschwindigkeit und
Muskelgedächtnis: Routine aufbauen und im Prüfungstempo bleiben. Die Antwortdateien der
JSONPath-Aufgaben werden in `/home/ubuntu/answers/` gespeichert.

## Ziel

Den Stoff der Kurskapitel festigen:

- [Kapitel 7. Services: ClusterIP, NodePort, LoadBalancer, Endpoints](../../course/07/de.md) — Service-Typen, Veröffentlichen per `expose`, Endpoints
- [Kapitel 31. Der Service von innen, DNS und CoreDNS](../../course/31/de.md) — headless Service (`clusterIP: None`), DNS-Namen
- [Kapitel 32. Ingress und Ingress-Controller](../../course/32/de.md) — Routing nach Host und Pfad zum Backend-Service
- [Kapitel 34. NetworkPolicy](../../course/34/de.md) — default-deny, podSelector, policyTypes

## Was wir tun und warum

| Block | Aufgaben | Fähigkeit |
|-------|----------|-----------|
| **Services** | Deployment `web`, ClusterIP, NodePort, headless | eine Last schnell mit verschiedenen Service-Typen veröffentlichen (Kapitel 7, 31) |
| **Routing und Isolierung** | Ingress `web-ing`, NetworkPolicy `deny-all` | Ingress-Regeln nach Host und default-deny für den Traffic (Kapitel 32, 34) |
| **JSONPath** | nodePort des Service `web-np` → in eine Datei | Daten per `-o jsonpath` unter Zeitdruck auslesen (Kapitel 47) |

## Infrastruktur

Die Umgebung wird in AWS (`eu-central-1`) über Terragrunt ausgerollt und besteht aus:

| Komponente | Beschreibung                                                         |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` mit öffentlichen Subnetzen                        |
| `ssh-keys` | SSH-Schlüssel für den Zugriff auf die Nodes                           |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ein Node   |
| `worker`   | Arbeitsmaschine mit `kubectl` und `check_result`                      |

Instanzen: `t4g.medium` (Master), Ubuntu `22.04`. Der Cluster hat einen Node — beim Master
ist der Taint `control-plane` entfernt, daher werden Pods direkt auf ihm geplant.

## Bereitstellung

```bash
TASK=120 make run_cka_task
```

Verbinde dich nach dem Erstellen per SSH mit der Arbeitsmaschine (Worker) und erledige die
Aufgaben von dort. `kubectl` ist bereits auf den Kontext `cluster1-admin@cluster1`
eingestellt.

Nützliche Befehle auf der Arbeitsmaschine:

```bash
time_left       # wie viel Zeit noch bleibt
check_result    # Lösung prüfen
```

## Aufgaben

---
|        **1**        | **Deployment**                                              |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle den Namespace `net` und darin ein Deployment `web` mit dem Image `viktoruj/ping_pong:latest` und 2 Replicas (`kubectl create ns net`, `kubectl -n net create deployment web --image=viktoruj/ping_pong:latest --replicas=2`). |
| Abnahmekriterien    | - Deployment `web` (ns `net`): 2 bereite Replicas. |
---
|        **2**        | **ClusterIP**                                               |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Veröffentliche das Deployment `web` als Service vom Typ ClusterIP mit dem Namen `web-svc` auf Port 80 (`kubectl -n net expose deployment web --name=web-svc --port=80 --target-port=8080`). |
| Abnahmekriterien    | - Service `web-svc` (ns `net`): Endpoints sind nicht leer. |
---
|        **3**        | **NodePort**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle einen Service `web-np` vom Typ NodePort für `web` mit dem festen `nodePort: 30080` (`kubectl -n net create service nodeport web-np --tcp=80:8080 --node-port=30080`). |
| Abnahmekriterien    | - Service `web-np`: Typ `NodePort`, `nodePort` 30080. |
---
|        **4**        | **Headless Service**                                        |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle einen headless Service `web-h` mit `clusterIP: None` für die `web`-Pods (Selector `app=web`). Ein headless Service verteilt DNS-Einträge direkt auf die Pods, ohne die virtuelle IP. |
| Abnahmekriterien    | - Service `web-h`: `clusterIP` = `None`. |
---
|        **5**        | **Ingress**                                                 |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle einen Ingress `web-ing` im Namespace `net`: Host `web.local`, der Pfad `/` leitet auf den Backend-Service `web-svc` Port 80 (`kubectl -n net create ingress web-ing --rule="web.local/*=web-svc:80"`). |
| Abnahmekriterien    | - Host-Regel `web.local` → Backend-Service `web-svc`, Port 80. |
---
|        **6**        | **NetworkPolicy (default-deny)**                            |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle eine NetworkPolicy `deny-all` im Namespace `net` mit einem leeren `podSelector: {}` (gilt für alle Pods) und `policyTypes: [Ingress]` — die Policy verbietet allen eingehenden Traffic. |
| Abnahmekriterien    | - NetworkPolicy `deny-all`: `policyTypes` enthält `Ingress`, `podSelector` ist leer. |
---
|        **7**        | **JSONPath**                                                |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Lies den `nodePort` des Service `web-np` per `-o jsonpath` aus und speichere ihn in `/home/ubuntu/answers/nodeport.txt` (Pfad `{.spec.ports[0].nodePort}`). |
| Abnahmekriterien    | - Der Wert in `nodeport.txt` stimmt mit `.spec.ports[0].nodePort` des Service `web-np` überein. |
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

Domäne Services & Networking (20 % CKA / 20 % CKAD) — Basiswiederholungen zu Services,
Ingress und NetworkPolicy.

## Löschen von Cluster und Ressourcen

```bash
TASK=120 make delete_cka_task
```
