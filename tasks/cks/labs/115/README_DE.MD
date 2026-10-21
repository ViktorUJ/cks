[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 - Cilium bootstrap, kube-proxy replacement und Mutual Authentication

> **Advanced / production track. Kein Bestandteil der formalen Anforderungen des CKS Core exam.**
> Dieses Lab geht über den Rahmen der CKS-Prüfung hinaus und ist als production-Fähigkeit nützlich: Installation von
> Cilium von Grund auf als vollständiger Ersatz für kube-proxy und Cilium Mutual Authentication auf
> Basis von SPIRE. Wenn du dich nur auf die Prüfung vorbereitest, haben die Labs 101-114 Priorität.

## Beschreibung

Die control-plane dieses Labs wird über `kubeadm init --skip-phases=addon/kube-proxy` hochgefahren - ohne das
`kube-proxy` DaemonSet und **ohne installiertes CNI**. Der Node bleibt `NotReady`, bis du
Cilium selbst installierst. Das ist bewusst so: Das Lab handelt ganz von der manuellen Installation von Cilium als
vollständiger Ersatz für kube-proxy (`kubeProxyReplacement`), dem inkrementellen Aktivieren von WireGuard
transparent encryption und Cilium Mutual Authentication auf Basis von SPIRE - jeder Schritt
wird einzeln installiert und geprüft und nicht fertig vorgegeben.

Die `cilium`/`hubble` CLI sind auf dem worker bereits installiert und zeigen auf den echten Cluster
(`~/.kube/config`), aber die eigentliche Installation von Cilium im Cluster führst du selbst durch.

## Bereitstellung

```bash
TASK=115 make run_cks_task
```

Verbinde dich nach der Bereitstellung per SSH mit dem Befehl aus der Terraform-Ausgabe (`worker_pc_ssh`).
Der Node ist direkt nach dem Login `NotReady` - das ist die erwartete baseline und kein Fehler.

## Ziel

Cilium als vollständigen Ersatz für kube-proxy auf einem bereits hochgefahrenen kube-proxy-freien
kubeadm-Cluster installieren, WireGuard encryption aktivieren, Cilium Mutual Authentication
(SPIRE) aktivieren und eine `CiliumNetworkPolicy` schreiben, die eine erfolgreiche mutual authentication zwischen
zwei Namespaces verlangt.

## Infrastruktur

| Komponente | Zweck |
| --- | --- |
| control-plane EC2 | kubeadm-Cluster ohne kube-proxy und ohne CNI zum Zeitpunkt der Ausgabe des Labs |
| `ingress-115` | Namespace des Clients, der die mutual authentication bestehen muss |
| `app-115` | Namespace des Backends, das durch eine CiliumNetworkPolicy geschützt ist, mit `authentication.mode: required` |
| worker EC2 | `cilium`/`hubble` CLI, konfiguriertes kubeconfig |

## Aufgaben

---

| **1** | **Baseline: kube-proxy-frei, ohne CNI** |
| :---: | :--- |
| Was wir tun | • Bestätige den aktuellen Zustand des Clusters, bevor du irgendetwas installierst |
| Abnahmekriterien | • Das `kube-proxy` DaemonSet fehlt<br/>• Das anfängliche `NotReady` wird vor der Installation von Cilium beobachtet<br/>• Der Checker bestätigt nach der Erledigung aller Aufgaben das Fehlen von kube-proxy und die Verfügbarkeit der API und nicht das historische `NotReady` |
| Prüfung | `kubectl -n kube-system get ds kube-proxy` -> `NotFound`. `kubectl get nodes` -> `NotReady` (kein CNI). |

---

| **2** | **Installation von Cilium als Ersatz für kube-proxy** |
| :---: | :--- |
| Was wir tun | • Installiere den Cilium agent/chart der Version `1.20.1` über die auf dem worker installierte `cilium` CLI der Version `v0.19.7`, mit `kubeProxyReplacement=true` und explizit gesetzten `k8sServiceHost`/`k8sServicePort`, die auf den echten API server zeigen (nicht auf den Service ClusterIP - ohne kube-proxy erreicht der Traffic an die ClusterIP von `kubernetes.default` den API server nicht, bevor Cilium selbst hochgefahren ist) |
| Abnahmekriterien | • `KubeProxyReplacement: True/Strict` (in `cilium-dbg status` des Agents)<br/>• Der Node wird `Ready`<br/>• Der ClusterIP Service ist ohne kube-proxy erreichbar |
| Prüfung | `cilium status --wait`, `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep KubeProxyReplacement`, dann `kubectl get nodes` -> `Ready`. Aus einem Test-Pod: `curl https://kubernetes.default.svc.cluster.local/` muss eine HTTP response erhalten (keinen connection error). |

---

| **3** | **WireGuard transparent encryption** |
| :---: | :--- |
| Was wir tun | • Aktiviere `encryption.enabled=true`, `encryption.type=wireguard` auf dem bereits installierten Cilium (`cilium upgrade`, keine Neuinstallation von Grund auf) |
| Abnahmekriterien | • `Encryption: Wireguard` in `cilium-dbg status` und `enable-wireguard: "true"` in der Cilium-ConfigMap<br/>• Der Pfad aus Aufgabe 2 weist keine Regression auf<br/>• Der Ein-Node-Teststand bestätigt die aktivierte WireGuard-Konfiguration, belegt aber keinen verschlüsselten Traffic zwischen Nodes (Peers: 0) |
| Prüfung | `kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status \| grep Encryption`. Wiederhole das curl aus Aufgabe 2 - es muss wieder eine HTTP response erhalten. |

---

| **4** | **Cilium Mutual Authentication (SPIRE)** |
| :---: | :--- |
| Was wir tun | • Aktiviere die eingebaute Installation von SPIRE über das Cilium helm chart selbst: `authentication.mutual.spire.enabled=true`, `authentication.mutual.spire.install.enabled=true` |
| Abnahmekriterien | • Das `spire-server` StatefulSet und das `spire-agent` DaemonSet haben alle angeforderten Ready-Replicas im Namespace `cilium-spire` |
| Prüfung | `kubectl get pods -A \| grep spire` - beide Arten von Pods im Zustand `Running` und Ready. |

> **Besonderheiten des Teststands.** Im Cluster gibt es keine StorageClass, daher braucht der SPIRE-Server einen ephemeren
> Speicher (`authentication.mutual.spire.install.server.dataStorage.enabled=false`). Das Image
> `spire-server` läuft als uid 1000 und kann im hostPath-Verzeichnis `root:755` keinen Socket erstellen -
> starte es als root (`authentication.mutual.spire.install.server.securityContext.runAsUser=0`).
> Außerdem verlangt das chart `authentication.enabled=true`. Details siehe Referenzlösung.

---

| **5** | **CiliumNetworkPolicy mit verpflichtender mutual authentication** |
| :---: | :--- |
| Was wir tun | • Erstelle `ingress-115` (client) und `app-115` (backend, label `app=backend`, Service `backend`)<br/>• Erstelle die `CiliumNetworkPolicy backend-auth-required` in `app-115`: `endpointSelector` auf `app=backend`, ingress nur aus dem Namespace `ingress-115` und `authentication.mode: required` für diese ingress-Regel |
| Abnahmekriterien | • Die policy selektiert das backend genau, enthält eine ingress-Regel aus `ingress-115` auf TCP/80 mit `authentication.mode: required`<br/>• Es gibt keine zusätzlichen ingress-Regeln und keine Umgehungspfade<br/>• Im isolierten Teststand von Lab 115 gibt es keine anderen namespaced/global network policies, die das backend beeinflussen<br/>• Der Service `backend` zeigt auf den Ready Pod `backend` |
| Prüfung | `kubectl -n app-115 get ciliumnetworkpolicy backend-auth-required -o yaml` - prüfe `authentication.mode: required` innerhalb von `ingress[0]`. |

---

| **6** | **Positive/negative control: eine authenticated identity ist erlaubt, eine fremde nicht** |
| :---: | :--- |
| Was wir tun | • Prüfe die Wirkung der policy mit Live-Traffic: Ein Client aus `ingress-115` muss `backend` erreichen (nach einem erfolgreichen SPIRE-based mutual auth handshake)<br/>• Ein separater Pod aus dem "falschen" Namespace (`app-115`, nicht `ingress-115`; Traffic des Backends zu sich selbst lässt Cilium immer durch) muss blockiert werden |
| Abnahmekriterien | • In einem isolierten gespiegelten backend erlaubt die baseline beide Clients, nach dem Anwenden einer Kopie der policy ist nur `ingress-115` erlaubt<br/>• Das aktive backend antwortet dem erlaubten Client, lehnt Clients aus `app-115` und aus einem neuen unabhängigen Namespace ab<br/>• Die Cilium BPF auth map enthält `spire` für das exakte Paar der identities von Client/backend |
| Prüfung | `curl` aus einem client-Pod in `ingress-115` an `http://backend.app-115.svc.cluster.local/` -> HTTP response. Dasselbe curl aus einem Pod in `app-115` ohne client-label -> connection error. |

## Prüfung

```bash
check_result
```

Der Checker **entfernt niemals** die aktive `app-115/backend-auth-required`. Zur Prüfung der baseline erstellt er ein temporäres gespiegeltes backend und einen Service in einem einmaligen Namespace `cks-115-*`, prüft zuerst den erlaubten Traffic ohne policy und wendet dann eine Kopie der geprüften CiliumNetworkPolicy nur auf das gespiegelte backend an. Separat werden das echte backend, EndpointSlice, die exakten Paare der SPIRE identities in der BPF auth map und das Verbot für Clients aus fremden Namespaces geprüft. Alle erstellten Pods, Services, policies und der temporäre Namespace werden mit einer cleanup-Prüfung gelöscht.

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=115 make delete_cks_task
```
