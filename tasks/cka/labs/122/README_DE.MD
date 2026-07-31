[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 122 — Drills: Pod-Scheduling

## Beschreibung

Ein Geschwindigkeitstrainer für die Domäne Workloads & Scheduling: kurze, unabhängige
Aufgaben zu nodeSelector, nodeAffinity, requests/limits, PriorityClass und
taints/tolerations. Der Cluster hat einen Node — Labels und Taints werden am einzigen Node
gesetzt.

Die Aufgaben sind im Prüfungsstil formuliert, mit automatischer Prüfung über den Befehl
`check_result`. Das Ziel eines Drills ist nicht die Theorie, sondern Geschwindigkeit und
Muskelgedächtnis: Routine im Steuern des Pod-Schedulings bekommen und das Prüfungstempo
halten.

> **Wichtig:** Aufgabe 6 (Taint) zuletzt erledigen — der Taint `NoSchedule` verhindert das
> Einplanen von Pods ohne Toleration.

## Ziel

Den Stoff der Kurskapitel festigen:

- [Kapitel 12. Pod-Scheduling: nodeName, nodeSelector, affinity](../../course/12/de.md) — Pods über nodeSelector und nodeAffinity an Nodes binden
- [Kapitel 13. Taints und Tolerations](../../course/13/de.md) — Pods durch Taints abweisen und über Tolerations zulassen
- [Kapitel 14. Ressourcen: requests, limits, LimitRange, ResourceQuota](../../course/14/de.md) — CPU-/Speicher-Requests und -Limits pro Container
- [Kapitel 15. Static Pods, PriorityClass, mehrere Scheduler](../../course/15/de.md) — Pod-Priorität über PriorityClass

## Was wir tun und warum

| Block | Aufgaben | Fähigkeit |
|-------|----------|-----------|
| **Bindung an einen Node** | Label `disk=ssd`, Pod `sel` (nodeSelector), Pod `aff` (nodeAffinity) | Pods auf die gewünschten Nodes lenken (Kapitel 12) |
| **Ressourcen und Priorität** | Pod `res` (requests/limits), PriorityClass `high-prio` + Pod `prio` | requests/limits und Scheduling-Priorität (Kapitel 14, 15) |
| **Taints und Tolerations** | Taint `dedicated=special:NoSchedule` + Pod `tol` | Isolierung eines Nodes per Taint und Zulassung über Toleration (Kapitel 13) |

## Infrastruktur

Die Umgebung wird in AWS (`eu-central-1`) über Terragrunt ausgerollt und besteht aus:

| Komponente | Beschreibung                                                                    |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` mit öffentlichen Subnetzen                                   |
| `ssh-keys` | SSH-Schlüssel für den Zugriff auf die Nodes                                      |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ein Node; Namespace `sched` ist vorab erstellt |
| `worker`   | Arbeitsmaschine mit `kubectl` und `check_result`                                |

Instanzen: `t3.medium` (Master), Ubuntu `22.04`. Der Cluster hat einen Node — beim Master
ist der Taint `control-plane` entfernt, daher werden Pods direkt auf ihm geplant.

## Bereitstellung

```bash
TASK=122 make run_cka_task
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

Den Namen des einzigen Nodes legt man am besten in eine Variable:
`NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')`.

---
|        **1**        | **Label auf dem Node**                                      |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Hänge an den Node das Label `disk=ssd` (`kubectl label node $NODE disk=ssd`). |
| Abnahmekriterien    | - der Node hat das Label `disk=ssd`. |
---
|        **2**        | **nodeSelector**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle den Pod `sel` (ns `sched`, Image `viktoruj/ping_pong:latest`) mit `nodeSelector: disk=ssd` — der Pod wird nur auf einem Node mit diesem Label eingeplant. |
| Abnahmekriterien    | - Pod `sel` ist im Zustand `Running`, `nodeSelector` `disk=ssd`. |
---
|        **3**        | **nodeAffinity**                                            |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle den Pod `aff` (ns `sched`, Image `viktoruj/ping_pong:latest`) mit required nodeAffinity: Schlüssel `disk`, Operator `In`, Werte `[ssd]` (`requiredDuringSchedulingIgnoredDuringExecution`). |
| Abnahmekriterien    | - Pod `aff` ist im Zustand `Running`, nodeAffinity ist gesetzt. |
---
|        **4**        | **requests / limits**                                       |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle den Pod `res` (ns `sched`, Image `viktoruj/ping_pong:latest`) mit den requests `cpu=100m`, `memory=64Mi` und den limits `cpu=200m`, `memory=128Mi` am Container. |
| Abnahmekriterien    | - Pod `res` ist im Zustand `Running`, die limits `cpu` und `memory` sind gesetzt. |
---
|        **5**        | **PriorityClass**                                           |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle die PriorityClass `high-prio` mit dem Wert `value: 1000` (`kubectl create priorityclass high-prio --value=1000`), dann den Pod `prio` (ns `sched`, Image `viktoruj/ping_pong:latest`) mit `priorityClassName: high-prio`. |
| Abnahmekriterien    | - PriorityClass `high-prio` `value=1000`;<br/>- Pod `prio` ist im Zustand `Running` mit `priorityClassName: high-prio`. |
---
|        **6**        | **Taint + Toleration** (als Letztes)                        |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Hänge an den Node den Taint `dedicated=special:NoSchedule` (`kubectl taint node $NODE dedicated=special:NoSchedule`), erstelle dann den Pod `tol` (ns `sched`, Image `viktoruj/ping_pong:latest`) mit der passenden Toleration (`key=dedicated`, `operator=Equal`, `value=special`, `effect=NoSchedule`). **Erledige diese Aufgabe als Letztes** — der Taint verhindert das Einplanen der übrigen Pods. |
| Abnahmekriterien    | - der Node hat den Taint `dedicated=special:NoSchedule`;<br/>- Pod `tol` ist im Zustand `Running`. |
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

Die Domäne Workloads & Scheduling (15 % CKA) — Wiederholungen von nodeSelector/affinity,
Ressourcen, PriorityClass, taints/tolerations.

## Löschen von Cluster und Ressourcen

```bash
TASK=122 make delete_cka_task
```
