[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 113 - Upgrade eines Kubernetes-Clusters mit kubeadm (minor upgrade)

## Ziel

In diesem CKS-Lab führst du ein echtes minor-upgrade eines selbstverwalteten
Clusters mit `kubeadm` durch: zuerst die control-plane, dann den worker-Node, in der richtigen
Reihenfolge und ohne ungeplante downtime des bereits laufenden workloads. Der Cluster startet
mit Kubernetes `1.35.x`; deine Aufgabe ist es, beide Nodes auf `1.36.x` zu bringen und dabei die
offizielle Prozedur `kubeadm upgrade` und das Umschalten des Paket-Repositorys
`pkgs.k8s.io` auf das neue minor einzuhalten.

## Prüfe dich vor dem Start

<details>
<summary>1. Warum verlangt `kubeadm upgrade` ein upgrade der control-plane STRIKT vor den worker-Nodes und nicht in beliebiger Reihenfolge?</summary>

`kubeadm upgrade apply` auf der control-plane aktualisiert die Version des API servers und der übrigen control-plane-Komponenten; von dieser Version aus wird die version skew policy des Clusters bemessen. Ein worker-Node mit einem zu neuen kubelet relativ zum API server kann den unterstützten skew verletzen (das kubelet darf nicht neuer sein als kube-apiserver). Das vorherige Aktualisieren der control-plane garantiert, dass der API server bereits auf der Zielversion ist, wenn der worker auf dieselbe wechselt - das ist keine willkürliche Empfehlung, sondern eine Anforderung der version skew policy von Kubernetes.
</details>

<details>
<summary>2. Warum ist das Umschalten des apt-Repositorys `pkgs.k8s.io` beim Wechsel auf ein neues minor zwingend, obwohl patch-Updates ohne das funktionieren?</summary>

Seit der Migration von `packages.cloud.google.com`/`apt.kubernetes.io` ist `pkgs.k8s.io` als **separates Repository für jede minor-Version** organisiert (`core:/stable:/v1.35`, `core:/stable:/v1.36` usw.) und nicht als ein einziges Repository mit allen Versionen. Innerhalb des bereits eingebundenen repos `v1.35` sind nur die patch-Releases `1.35.x` verfügbar. Damit `apt install kubeadm=1.36.x-*` die Versionen `1.36` sieht, muss man zuerst genau das repo `core:/stable:/v1.36` in `sources.list.d/kubernetes.list` einbinden (nur die Version in der URL ändert sich; der keyring mit dem Signaturschlüssel `Release.key` bleibt derselbe).
</details>

<details>
<summary>3. Warum ist `kubectl drain` vor dem upgrade des Clusters nicht einfach „gute Praxis“, sondern ein konkreter Schutz wovor?</summary>

`kubeadm upgrade` auf der control-plane erstellt die static Pod-Manifeste der Komponenten (kube-apiserver, controller-manager, scheduler) neu, und auf jedem Node erfordert das upgrade des kubelets dessen restart - in diesem Moment verliert der Node vorübergehend die Fähigkeit, den Status der Pods korrekt zu melden und neue anzunehmen. `drain` verlagert die gewöhnlichen workload-Pods vorab auf andere Nodes (oder markiert sie als evicted), damit dieser vorübergehende Ausfall des Nodes nicht zur downtime der Anwendung wird. Ohne `drain` können Pods auf dem zu aktualisierenden Node für die Dauer des restarts nicht verfügbar sein, ohne dass ein ausgleichender Umzug auf einen anderen Node stattfindet.
</details>

## Bezug zum Kurs

- [Kapitel 13. Kubernetes aktualisieren, um Schwachstellen zu beheben](../../course/13/de.md)

## Infrastruktur

Terragrunt erstellt ein self-managed Kubernetes `1.35.4` in `eu-central-1`, containerd,
Calico CNI:

| Komponente | Zweck |
|---|---|
| `k8s-1` control-plane | gewöhnlicher control-plane-Node, der gewöhnliche Pods zulässt (single control-plane, ohne dedizierten zweiten control-plane-Node) |
| `k8s-1` worker `worker1` | gewöhnlicher worker-Node auf derselben Startversion |
| `worker` | Arbeitsmaschine mit `kubectl`, `check_result` und SSH-Zugriff auf beide Nodes des Clusters |

Die Zielversion des upgrades ist `1.36.x` (der letzte verfügbare patch zum Zeitpunkt des Labs), das heißt,
nach der Erledigung der Aufgaben befindet sich der Cluster auf derselben training baseline-Version wie die
übrigen core labs 101-112. Das Überspringen von minor-Versionen (zum Beispiel ein direkter Wechsel `1.35` → `1.37`)
unterstützt kubeadm nicht - in diesem Lab ist ein solcher Wechsel auch nicht erforderlich.

Für den Zugriff auf die Nodes verwende die Aliase `k8s113_controlPlane_1` und `k8s113_node_worker1`.

Der Namespace `upgrade-113` mit dem Deployment `canary` (2 Replicas) ist bereits bereitgestellt - das ist dein
Indikator für das Fehlen von downtime. Während des gesamten upgrades muss mindestens eine Replica
`Available` bleiben; nach dem `uncordon` jedes Nodes und am Ende muss sich das Deployment
auf `2/2` erholen. Der Bootstrap verteilt beide Replicas vorab auf verschiedene
Nodes (required `podAntiAffinity`) und erstellt ein `PodDisruptionBudget` mit `minAvailable: 1`.

## Bereitstellung

```bash
TASK=113 make run_cks_task
```

Verbinde dich mit der Arbeitsmaschine und wähle den fertigen Kontext:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Erstelle das Verzeichnis für die Nachweise, bevor du mit der Arbeit beginnst:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,4}
```

## Aufgaben

---
| **1** | **Upgrade der control-plane auf das Ziel-minor** |
| :---: | :--- |
| Was wir tun | • Melde dich auf `k8s113_controlPlane_1` an (`ssh`, dann `sudo -i`).<br/>• Schalte das apt-Repository `pkgs.k8s.io` von `core:/stable:/v1.35` auf `core:/stable:/v1.36` um: In `/etc/apt/sources.list.d/kubernetes.list` ändert sich nur die Version in der URL (so ist es in der Dokumentation von Kubernetes beschrieben, der keyring bleibt derselbe).<br/>• Aktualisiere das Paket `kubeadm` auf `1.36.x`, führe `kubeadm upgrade plan` aus, dann `kubeadm upgrade apply v1.36.x`.<br/>• Führe erst nach erfolgreichem `apply` `kubectl drain` für diesen Node aus.<br/>• Aktualisiere die Pakete `kubelet`/`kubectl` auf `1.36.x`, starte das `kubelet` neu, führe dann `kubectl uncordon` aus. |
| Abnahmekriterien | • `kubeadm version`, `kubelet --version`, das lokale `kubectl version --client` und die Version des API server (`kubectl version`) melden auf der control-plane `v1.36.x`.<br/>• Der control-plane-Node (`<cp-name>` aus `kubectl get no`) hat den Status `Ready`.<br/>• Die vollständige Ausgabe des Befehls `kubeadm upgrade apply` (mit der Zeile `SUCCESS` und der Zielversion) ist wortwörtlich in `/var/work/tests/artifacts/1/kubeadm-upgrade-apply.txt` auf der Arbeitsmaschine gespeichert (der Befehl wird auf dem Node ausgeführt, die Ausgabe wird in eine Datei auf dem Node geschrieben und dann per `scp` kopiert). |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

Die Reihenfolge ist entscheidend: zuerst `apt-mark unhold kubeadm` → Paket aktualisieren → `apt-mark hold kubeadm` → `kubeadm upgrade plan` → `kubeadm upgrade apply vX.Y.Z`, und erst NACH erfolgreichem `apply` - `drain` und das Aktualisieren von `kubelet`/`kubectl`. `kubelet` vor dem Aufruf von `kubeadm upgrade apply` zu aktualisieren ist nicht nötig und wird von der offiziellen Prozedur nicht empfohlen. Speichere die Ausgabe von `kubeadm upgrade apply` in einer Datei auf dem Node (`> /tmp/kubeadm-upgrade-apply.txt 2>&1`) und rekonstruiere sie nicht hinterher aus dem Gedächtnis - der Test sucht nach dem wortwörtlichen Text mit dem Wort `SUCCESS`.
</details>

---
| **2** | **Upgrade des worker-Nodes auf das Ziel-minor** |
| :---: | :--- |
| Was wir tun | • Schalte auf dem Node `k8s113_node_worker1` (`ssh`, `sudo -i`) analog das Repository `pkgs.k8s.io` auf `core:/stable:/v1.36` um und aktualisiere `kubeadm`.<br/>• Führe `kubeadm upgrade node` aus (nicht `apply` - das ist ein Befehl nur für die control-plane).<br/>• Führe `kubectl drain` für diesen Node aus (von der Arbeitsmaschine aus, nicht vom Node selbst).<br/>• Aktualisiere `kubelet`/`kubectl`, starte das `kubelet` neu, führe `kubectl uncordon` aus. |
| Abnahmekriterien | • `kubeadm version`, `kubelet --version` und das lokale `kubectl version --client` melden auf dem worker-Node `v1.36.x`.<br/>• `kubectl get nodes` zeigt für den worker-Node `v1.36.x` in `kubeletVersion` und den Status `Ready`.<br/>• Die Ausgabe von `kubeadm upgrade node` ist in einer Datei auf dem Node gespeichert und per `scp` nach `/var/work/tests/artifacts/2/kubeadm-upgrade-node.txt` auf die Arbeitsmaschine kopiert. |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

`kubeadm upgrade node` ist genau der Befehl für worker-Nodes (und für zusätzliche control-plane-Nodes), `kubeadm upgrade apply` ist nur für den ERSTEN/einzigen control-plane-Node vorgesehen. Beginne diese Aufgabe erst, nachdem Aufgabe 1 vollständig abgeschlossen ist und die control-plane bereits `Ready` auf `1.36.x` ist - sonst verletzt du die version skew policy.
</details>

---
| **3** | **Die richtige Reihenfolge des upgrades einhalten** |
| :---: | :--- |
| Was wir tun | • Führe das upgrade der control-plane (Aufgabe 1) vollständig durch, einschließlich uncordon, BEVOR du das upgrade des worker-Nodes (Aufgabe 2) beginnst.<br/>• Diese Aufgabe erfordert keine gesonderte Aktion im Cluster: Die Reihenfolge wird automatisch von einem checker-owned Monitor des Zustands von Cluster und Versionen geprüft. |
| Abnahmekriterien | • Der checker-owned Monitor hält die ursprüngliche `1.35.x` baseline fest.<br/>• Danach wird der vollständige Übergang der control-plane auf `1.36.x` festgehalten (einschließlich `Ready` und schedulable), während der worker auf `1.35.x` ist, und erst danach der Beginn des upgrades des worker-Nodes.<br/>• Der Zustand übersteht einen Neustart des Monitors; bei einer fehlenden baseline oder einer Beobachtungslücke von mehr als 60 Sekunden wird die Aufgabe nicht als bestanden gewertet. |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Wenn du das upgrade des worker-Nodes bereits vor der control-plane begonnen (oder gar abgeschlossen) hast - halte an: Den worker auf einfache Weise wieder auf die Pakete `1.35.x` zurückzusetzen ist nicht möglich; der richtige Weg ist, das upgrade der control-plane abzuschließen und dann das upgrade des worker-Nodes fortzusetzen/zu wiederholen. Entscheidend ist: Das nächste upgrade des worker-Nodes (wann auch immer es begonnen wird) muss nach dem vollständig abgeschlossenen upgrade der control-plane stattfinden. Beginne Aufgabe 2 nicht, bevor `kubectl get node <cp-name>` (der control-plane-Name aus `kubectl get no`) `v1.36.x` und `Ready` zeigt.
</details>

---
| **4** | **Das Fehlen von downtime beim bestehenden workload belegen** |
| :---: | :--- |
| Was wir tun | • Starte, während du die Aufgaben 1-2 ausführst, in einer separaten Sitzung auf der Arbeitsmaschine eine Schleife, die die Verfügbarkeit des Deployments `canary` im Namespace `upgrade-113` alle paar Sekunden abfragt.<br/>• Hänge jede Abfragezeile an `/var/work/tests/artifacts/4/canary-availability.log` an, im Format mit `available=N` (zum Beispiel `available=2`).<br/>• Setze die Abfrage während des gesamten upgrades beider Nodes fort. |
| Abnahmekriterien | • Das Deployment `canary` hat am Ende `2/2` verfügbare Replicas, das ursprüngliche Deployment/PDB und die required Pod anti-affinity sind erhalten.<br/>• Das Fehlen von downtime prüft der checker-owned Monitor anhand von Pod Ready und CRI-Containern genau aus `upgrade-113`; Fehler von API/SSH/CRI werden als UNKNOWN gezählt und nicht als null.<br/>• Die Student-Datei `/var/work/tests/artifacts/4/canary-availability.log` enthält mindestens zwei Zeilen im Format `<unix_timestamp> available=N` oder `<unix_timestamp> available=api-unreachable`, mit Beobachtungen vor dem upgrade der control-plane und nach dem Beginn des upgrades des workers. |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

Beispiel einer Abfrageschleife, die du in einem separaten Terminal/`screen`/`tmux` für die gesamte Dauer der Aufgaben 1-2 laufen lassen kannst: `while true; do if available=$(kubectl get deployment canary -n upgrade-113 -o jsonpath='{.status.availableReplicas}' 2>/dev/null); then echo "$(date +%s) available=${available:-0}"; else echo "$(date +%s) available=api-unreachable"; fi >> /var/work/tests/artifacts/4/canary-availability.log; sleep 5; done`. Wenn das Deployment kurzzeitig alle Replicas verloren hat - prüfe `kubectl get pods -n upgrade-113 -o wide` und ob die aufeinanderfolgenden drains das PDB und die required anti-affinity einhalten.
</details>

## Prüfung

```bash
check_result
```

Die Prüfung enthält `0 Init` und fünf obligatorische Tests. Die Tests 1-2 prüfen die Versionen von
`kubeadm`/`kubelet`/lokalem `kubectl` und den Status `Ready` auf der control-plane bzw. dem worker-Node
sowie die wortwörtliche evidence-Datei mit der Ausgabe von `kubeadm upgrade`. Test 3
prüft die Reihenfolge des upgrades anhand des checker-owned Monitors des Cluster-Zustands und nicht anhand der
Änderungszeit der Dateien. Test 4 prüft, dass der workload `canary` keinen Ausfall hatte,
und verwendet denselben checker-owned Monitor als maßgebliche Quelle. Test 5 ist die abschließende
Prüfung, dass beide Nodes tatsächlich auf der Zielversion sind und nicht im Zustand
`cordon` zurückgelassen wurden.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=113 make delete_cks_task
```
