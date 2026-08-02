[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 — Troubleshooting: Wir reparieren kaputte Ressourcen

## Beschreibung

Praxisübung zur Domäne Troubleshooting (30 % des CKA). Im Cluster sind bereits **kaputte**
Objekte ausgerollt — deine Aufgabe ist es, die Ursachen zu finden und zu beheben, indem du
eine systematische Debugging-Route anwendest: `get` → `describe` (Events) → `logs` →
Reparatur. Die Aufgaben simulieren typische Vorfälle: ImagePullBackOff, leere Endpoints
wegen eines falschen Selectors und CreateContainerConfigError wegen einer fehlenden
ConfigMap.

Alle Aufgaben sind im Prüfungsstil formuliert (wie echte CKA/CKAD-Fragen) mit automatischer
Prüfung über den Befehl `check_result`.

## Ziel

Den Stoff der Kurskapitel festigen:

- [Kapitel 44. Debugging von Anwendungsfehlern](../../course/44/de.md) — die Route `get` → `describe` → `logs`, Auswertung der Pod-Status
- [Kapitel 45. Debugging von Control Plane und Worker-Nodes](../../course/45/de.md) — Diagnose von Nodes und Systemkomponenten
- [Kapitel 46. Debugging von Services und Netzwerk](../../course/46/de.md) — die Kette Service ↔ Endpoints ↔ Labels

## Was wir reparieren und warum

In diesem Lab reparieren wir drei unabhängige Vorfälle: ein defektes Image, eine zerrissene
Verbindung zwischen Service und Pods sowie eine fehlende Konfiguration. Jeder Defekt übt
seinen eigenen Abschnitt der Debugging-Route:

| Defekt | Symptom | Ursache | Was es lehrt |
|--------|---------|---------|--------------|
| **ReplicaSet `rs-app2223`** (Namespace `rsapp`) | ImagePullBackOff | falscher Image-Tag | Analyse von Image-Problemen und Neuerstellung der RS-Pods (Kapitel 44) |
| **Service `svc-broken`** (Namespace `tsvc`) | leere Endpoints | der Selector passt nicht zu den Label der Pods | die Kette Service ↔ Endpoints ↔ Labels (Kapitel 46) |
| **Deployment `capp`** (Namespace `cfgapp`) | CreateContainerConfigError | die benötigte ConfigMap fehlt | Konfigurationsabhängigkeiten (Kapitel 44) |

Das Gesamtbild dessen, was ausgerollt wird:

```mermaid
flowchart LR
    a["rs-app2223<br>ImagePullBackOff"] -->|"fix image"| a2["2 ready"]
    b["svc-broken<br>Endpoints leer"] -->|"fix selector"| b2["Endpoints vorhanden"]
    c["capp<br>CreateContainerConfigError"] -->|"create ConfigMap"| c2["Ready"]
    a2 ~~~ b
    b2 ~~~ c
    style a fill:#db4437,color:#fff
    style b fill:#db4437,color:#fff
    style c fill:#db4437,color:#fff
    style a2 fill:#0f9d58,color:#fff
    style b2 fill:#0f9d58,color:#fff
    style c2 fill:#0f9d58,color:#fff
```

## Infrastruktur

Die Umgebung wird in AWS (`eu-central-1`) über Terragrunt ausgerollt und besteht aus:

| Komponente | Beschreibung                                                         |
|------------|----------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` mit öffentlichen Subnetzen                        |
| `ssh-keys` | SSH-Schlüssel für den Zugriff auf die Nodes                          |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ein Node; rollt beim Start die kaputten Objekte aus |
| `worker`   | Arbeitsmaschine mit `kubectl` und `check_result`                      |

Instanzen: `t3.medium` (Master), Ubuntu `22.04`. Der Cluster hat einen Node — beim Master
ist der Taint `control-plane` entfernt, daher werden Pods direkt auf ihm geplant.

## Bereitstellung

```bash
TASK=114 make run_cka_task
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
|        **1**        | **Das ReplicaSet reparieren**                               |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Im Namespace `rsapp` hängen die Pods des ReplicaSets `rs-app2223` in `ImagePullBackOff`. Gehe die Route durch: `kubectl get po -n rsapp` (wir sehen den Status), `kubectl describe po -n rsapp <pod>` (in Events — das Image `viktoruj/ping_pong:doesnotexist123` wird nicht gezogen). Korrigiere das Image im RS-Template auf ein funktionierendes (`viktoruj/ping_pong:latest`) über `kubectl edit rs rs-app2223 -n rsapp`. Ein RS erstellt die Pods bei einer Template-Änderung nicht neu — lösche die alten Pods (`kubectl delete po -n rsapp -l <label>`), damit das RS neue startet. Erreiche `2` bereite Replicas. |
| Abnahmekriterien    | - ReplicaSet `rs-app2223` (Namespace `rsapp`): `2` Ready-Replicas. |
---
|        **2**        | **Den Service reparieren (leere Endpoints)**                 |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Der Service `svc-broken` im Namespace `tsvc` liefert keinen Traffic — seine Endpoints sind leer. Diagnose: `kubectl get endpoints svc-broken -n tsvc` (leer), `kubectl describe svc svc-broken -n tsvc` (Selector, zum Beispiel `app=WRONG`), `kubectl get pods -n tsvc --show-labels` (die Pods tragen das Label `app=web`). Bringe den Selector des Services mit den echten Label der Pods in Übereinstimmung (`kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'`) und stelle sicher, dass die Endpoints gefüllt sind. |
| Abnahmekriterien    | - Service `svc-broken` (Namespace `tsvc`): Endpoints sind nicht leer (≥ 1 Adresse). |
---
|        **3**        | **Das Deployment reparieren (keine ConfigMap)**              |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Das Deployment `capp` im Namespace `cfgapp` fällt in `CreateContainerConfigError`. Die Route: `kubectl get po -n cfgapp` (wir sehen den Status), `kubectl describe po -n cfgapp <pod>` (in Events — die ConfigMap `missing-config` wird nicht gefunden). Erstelle die fehlende ConfigMap (`kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value`) und warte, bis das Deployment bereit wird (`kubectl rollout status deploy capp -n cfgapp`). |
| Abnahmekriterien    | - Deployment `capp` (Namespace `cfgapp`): ≥ 1 Ready-Replica. |
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

Das Lab deckt die Troubleshooting-Aufgaben der Mocks ab: CKAD mock 01 (Nr. 4 — fix
ReplicaSet); die allgemeine Troubleshooting-Fähigkeit aus CKA mock 01/02 (Auswertung von
Status, Endpoints, Konfiguration) und CKAD mock 02 (Nr. 7/Nr. 8 — fix ingress/netpol).

## Löschen von Cluster und Ressourcen

```bash
TASK=114 make delete_cka_task
```
