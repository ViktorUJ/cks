[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD)

# Lab 121 — Drills: RBAC

## Beschreibung

Geschwindigkeitstraining zu RBAC: kurze, unabhängige Aufgaben zu ServiceAccount,
Role/RoleBinding, ClusterRole/ClusterRoleBinding und zur Prüfung der effektiven Rechte mit
`kubectl auth can-i`. Der Namespace `rbac` ist bereits vorbereitet.

Die Aufgaben sind im Prüfungsstil formuliert und werden automatisch mit dem Befehl
`check_result` geprüft. Ziel des Drills ist nicht die Theorie, sondern Geschwindigkeit und
Muskelgedächtnis: das imperative Erstellen von RBAC-Objekten in die Finger bekommen und im
Prüfungstempo bleiben.

## Ziel

Den Stoff der Kurskapitel festigen:

- [Kapitel 21. ServiceAccount; Authentifizierung, Autorisierung, Admission](../../course/21/ru.md) — ServiceAccount, die Kette authn/authz/admission
- [Kapitel 38. RBAC: Role, ClusterRole und Bindings](../../course/38/ru.md) — Role/ClusterRole, RoleBinding/ClusterRoleBinding, Rechteprüfung mit `auth can-i`

## Was wir tun und warum

| Block | Aufgaben | Fähigkeit |
|-------|----------|-----------|
| **RBAC im Namespace** | ServiceAccount `app-sa`, Role `pod-reader`, RoleBinding `read-pods` | Rechte innerhalb eines Namespace über Role + Binding (Kapitel 38) |
| **Cluster-weites RBAC** | ClusterRole `cr-viewer`, ClusterRoleBinding `crb-viewer` | Zugriff auf Cluster-Ressourcen (nodes) über ClusterRole (Kapitel 38) |
| **Rechteprüfung** | `kubectl auth can-i` für `app-sa` | schnelle Validierung der effektiven Rechte eines ServiceAccount (Kapitel 21) |

## Infrastruktur

Die Umgebung wird in AWS (`eu-central-1`) über Terragrunt bereitgestellt und besteht aus:

| Komponente | Beschreibung                                                                    |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` mit öffentlichen Subnetzen                                   |
| `ssh-keys` | SSH-Schlüssel für den Zugriff auf die Nodes                                      |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ein Node; der Namespace `rbac` ist bereits vorbereitet |
| `worker`   | Arbeitsmaschine mit `kubectl` und `check_result`                                |

Instanzen: `t3.medium` (master), Ubuntu `22.04`. Der Cluster hat nur einen Node — beim
master wurde der Taint `control-plane` entfernt, daher werden Pods direkt darauf geplant.

## Bereitstellung

```bash
TASK=121 make run_cka_task
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
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle den ServiceAccount `app-sa` im Namespace `rbac` (`kubectl -n rbac create serviceaccount app-sa`). |
| Abnahmekriterien    | - ServiceAccount `app-sa` existiert im Namespace `rbac`. |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle die Role `pod-reader` im Namespace `rbac` mit den Rechten `get,list,watch` auf die Ressource `pods` (`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`). |
| Abnahmekriterien    | - Role `pod-reader` gewährt `get`/`list`/`watch` auf `pods`. |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle das RoleBinding `read-pods` im Namespace `rbac` und verbinde die Role `pod-reader` mit dem Subjekt ServiceAccount `app-sa` (`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`). |
| Abnahmekriterien    | - RoleBinding `read-pods` verweist auf die Role `pod-reader` und das Subjekt `app-sa`. |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle die ClusterRole `cr-viewer` mit den Rechten `get,list` auf die Cluster-Ressource `nodes` (`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`). |
| Abnahmekriterien    | - ClusterRole `cr-viewer` gewährt `get`/`list` auf `nodes`. |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Erstelle das ClusterRoleBinding `crb-viewer` und verbinde die ClusterRole `cr-viewer` mit dem Subjekt ServiceAccount `app-sa` aus dem Namespace `rbac` (`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`). |
| Abnahmekriterien    | - ClusterRoleBinding `crb-viewer` verweist auf die ClusterRole `cr-viewer` und das Subjekt `rbac/app-sa`. |
---
|        **6**        | **Rechteprüfung (auth can-i)**                              |
| :-----------------: | :----------------------------------------------------------- |
| Was wir tun         | Prüfe die effektiven Rechte von `app-sa` mit `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa`: `get pods` in `rbac`, `get nodes` und `delete pods` in `rbac`. Stelle sicher, dass die Bindings korrekt vergeben sind. |
| Abnahmekriterien    | - `get pods` im Namespace `rbac` = `yes`;<br/>- `get nodes` = `yes`;<br/>- `delete pods` im Namespace `rbac` = `no`. |
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

Die Domäne Cluster Architecture (RBAC) für CKA und Application Security für CKAD —
Wiederholungen von Role/ClusterRole und der Bindings an einen ServiceAccount.

## Löschen von Cluster und Ressourcen

```bash
TASK=121 make delete_cka_task
```
