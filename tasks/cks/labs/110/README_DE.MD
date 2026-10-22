[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 110 - gVisor RuntimeClass, Cilium WireGuard und Istio mTLS

## Ziel

In diesem CKS-Lab baust du drei unabhängige Schutzschichten für workloads zusammen: die sandboxed runtime
**gVisor** über `runsc`, die Cilium-WireGuard-Verschlüsselung zwischen Nodes und Istio
service-to-service-mTLS. Am Ende siehst du die Einstellungen nicht nur, sondern belegst sie mit beobachtbaren
Ergebnissen: dem Unterschied des kernel view von gVisor, WireGuard-Paketen ohne HTTP marker und dem unterschiedlichen
Ergebnis eines Aufrufs aus dem mesh und von einem plaintext-Client außerhalb des mesh.

## Prüfe dich vor dem Start

<details>
<summary>1. Wie unterscheidet sich der userspace kernel von gVisor grundsätzlich vom guest kernel einer virtuellen Maschine?</summary>

gVisor (`runsc`) implementiert eine eigene Teilmenge der Linux-syscalls IM USERSPACE, fängt die Systemaufrufe des Containers ab und verarbeitet sie selbst, ohne sie direkt an den Host-Kernel weiterzugeben - der Container-Prozess sieht einen anderen „Kernel“ (ein anderes `uname -r`, anderes Verhalten einiger syscalls). Ein guest kernel (zum Beispiel Kata Containers) startet einen VOLLWERTIGEN Linux-Kernel innerhalb einer leichtgewichtigen VM - stärkere Isolation, aber mit dem Overhead vollwertiger Virtualisierung, den gVisor nicht hat.
</details>

<details>
<summary>2. Was genau authentifiziert ein WireGuard peer, und warum ist das NICHT dasselbe wie die identity eines ServiceAccount?</summary>

WireGuard authentifiziert die NODES des Clusters über kryptografische Schlüssel, die Cilium für jeden Node erzeugt - die Verschlüsselung erfolgt auf Ebene des node-to-node-Tunnels. Das schützt den Traffic ZWISCHEN den Nodes vor dem Mithören auf Netzwerkebene, hat aber nichts mit der identity eines konkreten Pods/ServiceAccount innerhalb dieses Traffics zu tun - Cilium WireGuard prüft nicht, „wer“ der Absender auf Anwendungsebene ist, nur „welcher Node“.
</details>

<details>
<summary>3. Warum beweist ein erfolgreiches `curl` mit Code 200 innerhalb des mesh NICHT, dass ein plaintext client tatsächlich blockiert wurde?</summary>

Eine erfolgreiche Antwort INNERHALB des mesh beweist nur, dass die mTLS-Verbindung zwischen zwei sidecars funktioniert - das ist eine positive control. Um zu belegen, dass STRICT tatsächlich Traffic von AUSSERHALB des mesh blockiert, braucht es eine separate negative control: einen Client OHNE sidecar, der versucht, denselben Service aufzurufen, und eine Ablehnung erhält. Ein erfolgreicher Test allein genügt nicht - beide werden gebraucht: allowed für eine mesh identity, denied für plaintext.
</details>

## Bezug zum Kurs

- [Kapitel 22. Container Runtime Sandbox](../../course/22/de.md)
- [Kapitel 23. Pod-to-Pod-Verschlüsselung und mTLS](../../course/23/de.md)

## Infrastruktur

Terragrunt erstellt Kubernetes `1.36.0` in `eu-central-1`:

| Komponente | Zweck |
|---|---|
| `k8s-1` control-plane | gewöhnlicher containerd workload node, Cilium und `tcpdump` zum Mitschneiden von Paketen zwischen Nodes |
| `k8s-1` worker `gvisor` | separater Node mit containerd, installiertem `runsc` und CRI handler `runsc` |
| CNI | **Cilium** (installiert über das Cilium CLI mit dem Helm release `cilium`); WireGuard ist bis Aufgabe 4 absichtlich ausgeschaltet |
| `worker` | Arbeitsmaschine mit `kubectl`, `cilium`, `istioctl`, `check_result` und SSH aliases zu den Nodes |

Die am 2026-08-31 verifizierte Matrix (gleiche sie vor jedem Build ab): Kubernetes im Lab -
`1.36.0`; Cilium data plane - ein unterstützter lab-Build, dessen Kompatibilität mit
Kubernetes `1.36` anhand der aktuellen requirements matrix bestätigt werden muss; Cilium CLI `0.19.7`
(kompatibel mit Cilium `1.17+`); Istio `1.30.4` (der Zweig `1.30` unterstützt Kubernetes
`1.32–1.36` offiziell). Die Version der Prüfung bestimmt hier nicht die Kompatibilität des lab tooling; laut LF
ist sie derzeit `v1.34` und wird vor der Prüfung separat geprüft.

Nach dem bootstrap stehen zwei workload placement labels zur Verfügung:

```text
lab.cks.io/role=control-plane
sandbox.runtime/gvisor=true,lab.cks.io/role=gvisor
```

Die control-plane ist für gewöhnliche Pods ohne tolerations verfügbar. Der gVisor-Node ist zusätzlich mit dem taint
`sandbox.runtime/gvisor=true:NoSchedule` markiert: Auf ihn gelangen nur Pods, die diesen taint tolerieren
(Pods mit `RuntimeClass gvisor` erhalten die nötige toleration aus `scheduling.tolerations` der Klasse).

Die Namespaces `sandbox-110` und `market` existieren bereits. Bei `market` ist vorab das
Label `istio-injection=enabled` gesetzt; die Istio control plane ist nicht installiert. Für den Zugriff auf den
sandbox-Node vom worker verwende den alias `k8s110_node_gvisor`, für die control-plane -
`k8s110_controlPlane_1`.

## Bereitstellung

```bash
TASK=110 make run_cks_task
```

Verbinde dich mit der Arbeitsmaschine und wähle den fertigen Kontext:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Erstelle vor Beginn der Arbeit das Verzeichnis für die Nachweise:

```bash
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## Aufgaben

---
| **1** | **containerd runtime konfigurieren und RuntimeClass für runsc erstellen** |
| :---: | :--- |
| Was wir tun | • Auf `k8s110_node_gvisor` ist die Binärdatei `runsc` bereits installiert, aber der bootstrap hat absichtlich aus `/etc/containerd/config.toml` den Abschnitt `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]` mit `runtime_type = "io.containerd.runsc.v1"` entfernt - das ist eine typische Prüfungssituation mit defekter config.toml.<br/>• Stelle diesen Abschnitt wieder her (die Sicherungskopie liegt in `/etc/containerd/config.toml.bak`, oder ergänze ihn von Hand) und führe `sudo systemctl restart containerd` aus.<br/>• Erstelle eine `RuntimeClass` `gvisor` mit exaktem `handler: runsc`.<br/>• Setze in `scheduling` einen `nodeSelector` `sandbox.runtime/gvisor: "true"`, damit ein Pod mit dieser Klasse niemals auf einen gewöhnlichen Node gelangt, und `tolerations` für den taint des gVisor-Nodes (`sandbox.runtime/gvisor=true:NoSchedule`), sonst gelangt der Pod nicht dorthin. |
| Abnahmekriterien | • Auf dem Node ist `containerd` aktiv, und `config.toml` enthält einen funktionierenden Abschnitt `runtimes.runsc` mit `runtime_type = "io.containerd.runsc.v1"`<br/>• `kubectl get runtimeclass gvisor` existiert, der handler ist gleich `runsc`, in `scheduling` gibt es `nodeSelector` und `tolerations` für den taint des gVisor-Nodes<br/>• In `/var/work/tests/artifacts/1/runsc-runtime.txt` steht die exakte Zeile `RuntimeClass gvisor: handler runsc` |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

Die Sicherungskopie `/etc/containerd/config.toml.bak` ist der schnellste Weg zur Wiederherstellung, aber prüfe ihren Inhalt vor dem Zurückkopieren (`diff` mit der aktuellen Datei), um zu verstehen, was genau fehlt. Nach der Wiederherstellung des Abschnitts `runtimes.runsc` unbedingt `systemctl restart containerd` - das bloße Bearbeiten der Datei wendet die Änderungen nicht auf den bereits laufenden Prozess an.
</details>

---
| **2** | **Pod in der gVisor sandbox** |
| :---: | :--- |
| Was wir tun | • Erstelle in `sandbox-110` den Pod `gvisor-sandbox` mit `runtimeClassName: gvisor`, dem Container `app` und dem Image `busybox:1.36`.<br/>• Gib im Pod explizit `nodeSelector` `sandbox.runtime/gvisor: "true"` und `tolerations` für den taint des gVisor-Nodes an (dasselbe wie in `scheduling` der RuntimeClass; ohne sie fügt Kubernetes sie aus der RuntimeClass selbst hinzu, aber im Manifest ist das nicht zu sehen).<br/>• Starte im Container einen HTTP server auf `8080`, der die Zeile `CKS110-WIREGUARD-MARKER` zurückgibt.<br/>• Erstelle einen Service `gvisor-echo` auf `8080`, der diesen Pod auswählt.<br/>• Deaktiviere das automount des ServiceAccount token.<br/>• Schreibe die Ausgabe von `uname -r` und `dmesg` aus dem Pod in ein artifact: `dmesg` innerhalb der gVisor sandbox beginnt mit der Zeile `Starting gVisor...` statt mit dem echten Kernel-Log des Nodes - das ist ein direkter Beleg der Isolation, getrennt vom Unterschied von `uname -r`. |
| Abnahmekriterien | • Der Pod ist `Running` auf einem Node mit `sandbox.runtime/gvisor=true`, der Service wählt ihn aus, und `/var/work/tests/artifacts/2/gvisor-kernel.txt` enthält die Zeile `gvisor uname -r: <tatsächlicher Wert>` und die Zeile `Starting gVisor` aus der Ausgabe von `dmesg` |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Wenn der Pod nicht startet (hängt in `ContainerCreating` mit dem Event `FailedCreatePodSandBox`, zum Beispiel `no runtime for "runsc" is configured`), ist sehr wahrscheinlich Aufgabe 1 nicht vollständig abgeschlossen - die RuntimeClass muss tatsächlich auf einen funktionierenden containerd handler zeigen. Im verwendeten `busybox:1.36` gibt es das applet `httpd` - verwende `httpd -f -p 8080 -h /www` für einen minimalen HTTP server (das Vorhandensein des applet lässt sich über `busybox --list | grep '^httpd$'` prüfen).
</details>

---
| **3** | **Vergleich mit einem gewöhnlichen runc Pod** |
| :---: | :--- |
| Was wir tun | • Erstelle `runc-baseline` in `sandbox-110`: `busybox:1.36`, Container `app`, `sleep 3600`.<br/>• Ohne `runtimeClassName`, mit nodeSelector `lab.cks.io/role: control-plane` und ohne SA token.<br/>• Vergleiche sein `uname -r` mit dem gVisor Pod und speichere beide Ergebnisse in `/var/work/tests/artifacts/3/runtime-comparison.txt`. |
| Abnahmekriterien | • Der Baseline Pod ist `Running` auf der control-plane und hat kein `runtimeClassName`<br/>• Sein release unterscheidet sich vom gVisor release<br/>• Im artifact gibt es beide Zeilen `gvisor uname -r:` und `runc uname -r:` mit tatsächlichen Werten |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Dieser Pod wird gezielt auf einem ANDEREN Node platziert (control-plane, nicht dem gvisor-Node), über den nodeSelector `lab.cks.io/role: control-plane` - das ist nicht einfach „irgendein gewöhnlicher Pod“, sondern ein kontrollierter Vergleich mit einem bekannten Platzierungsort. Wenn `uname -r` für beide Pods gleich ausfällt - prüfe, ob `gvisor-sandbox` tatsächlich `runtimeClassName: gvisor` verwendet.
</details>

---
| **4** | **Cilium transparent encryption aktivieren** |
| :---: | :--- |
| Was wir tun | • Halte zuerst die Versionen von Kubernetes, Cilium agent und Cilium CLI in `/var/work/tests/artifacts/4/tool-versions.txt` fest und stelle sicher, dass die data plane Kubernetes `1.36` unterstützt.<br/>• Aktiviere WireGuard im vorhandenen Helm release, das von `cilium install` erstellt wurde: `cilium upgrade --version 1.20.1 --set encryption.enabled=true --set encryption.type=wireguard --wait`.<br/>• Starte die Agents neu (`kubectl -n kube-system rollout restart daemonset/cilium`): Helm ändert nur die ConfigMap, und das Template des DaemonSet bleibt dasselbe.<br/>• Prüfe `cilium-config` (`enable-wireguard: "true"`) und die Bereitschaft beider Cilium agents.<br/>• Ein direkter ConfigMap patch ist nur als kurzzeitige Lern-Baseline-Probe mit obligatorischem bestätigtem Rollback zulässig. Suche nicht nach dem Befehl `cilium encrypt enable`: Das `cilium` CLI auf dem Client hat keinen solchen Unterbefehl.<br/>• Speichere das agent-seitige `cilium-dbg encrypt status` und `cilium-dbg debuginfo --output json` in `/var/work/tests/artifacts/4/cilium-encrypt-status.txt` (`cilium-dbg status` hat kein Flag `--all-encryption`). |
| Abnahmekriterien | • Die Versions-evidence existiert und stimmt mit dem tatsächlichen Image des DaemonSet `kube-system/cilium` überein<br/>• Die Cilium agents (DaemonSet) sind vollständig Ready<br/>• Status zeigt WireGuard und zeigt nicht gleichzeitig IPsec<br/>• Das Debuginfo-JSON enthält evidence zu peer/allowed-IP (oder remote-node) für den Zustand zwischen den Nodes<br/>• Die ConfigMap `kube-system/cilium-config` enthält `enable-wireguard: "true"` als angewendete effective-Konfiguration aus den Helm values<br/>• Die Einstellung übersteht einen restart eines agent Pods (der Checker startet den Pod neu und prüft den Status erneut) |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

Verwende die Helm values des vorhandenen release `cilium` als langfristige source-of-truth zum Aktivieren von WireGuard und nicht ephemere Befehle - eine Änderung außerhalb der Helm values überlebt möglicherweise einen restart des Agents oder ein Update des Helm release nicht, und der Test prüft gezielt, dass die Einstellung einen restart übersteht. `cilium-dbg` wird INNERHALB des Agent-Pods über `kubectl exec` aufgerufen und nicht als separate lokale Binärdatei auf dem worker. `cilium-dbg status` hat KEIN Flag `--all-encryption` - für detaillierte peer/allowed-IP evidence verwende `cilium-dbg debuginfo --output json`.
</details>

---
| **5** | **Das Fehlen von plaintext zwischen den Nodes belegen** |
| :---: | :--- |
| Was wir tun | • Baue einen Baseline-Nachweis VORHER/NACHHER für denselben Flow zwischen Nodes.<br/>• **Baseline (WireGuard aus):** Starte auf der control-plane `tcpdump` für die IP des entfernten Nodes (`host <remote-node-ip>`, ohne vorherigen Filter nach `udp port 51871`); deaktiviere WireGuard vorübergehend (`enable-wireguard: "false"` in `cilium-config`, `rollout restart daemonset/cilium`); führe die Anfrage `runc-baseline -> gvisor-echo` aus; speichere diesen Baseline-capture und stelle sicher, dass darin der plaintext `CKS110-WIREGUARD-MARKER` zu sehen ist.<br/>• **Nachher (WireGuard an):** Stelle `enable-wireguard: "true"` wieder her, warte auf Ready und wiederhole DIESELBE Anfrage mit DEMSELBEN Capture-Scope (`host <remote-node-ip>`, ohne Filter nach Port).<br/>• Der Capture wird auf der control-plane aufgenommen (in eine Datei auf dem Node), dann per `scp` auf die Arbeitsmaschine nach `/var/work/tests/artifacts/5/wireguard-tcpdump.txt` kopiert: Darin darf jetzt nur noch WireGuard UDP/`51871` zu sehen sein, ohne plaintext marker. |
| Abnahmekriterien | • Der finale (post-change) Capture im selben peer/interface-Scope enthält UDP/`51871`, aber **nicht** `CKS110-WIREGUARD-MARKER`<br/>• Ein Aufruf zwischen verschiedenen Nodes erhält den marker erfolgreich in der HTTP-Antwort<br/>• Der Checker wiederholt den post-change Capture im selben peer/interface-Scope selbstständig (ohne sich vorab nur auf `udp port 51871` zu beschränken) und deaktiviert außerdem selbstständig WireGuard vorübergehend und stellt es danach wieder her, um seine eigene Baseline-Bestätigung zu erhalten, dass derselbe Flow im plaintext-Zustand den marker tatsächlich auf dem wire preisgibt |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

Mitschneiden musst du auf dem ECHTEN physischen Netzwerkinterface des Nodes (zum Beispiel `eth0`) und nicht auf dem virtuellen Interface des Pods/veth oder dem internen Cilium-Interface `cilium_wg0` - `cilium_wg0` trägt konstruktionsbedingt als Interface des WireGuard-Tunnels BEREITS ENTSCHLÜSSELTEN Traffic (das ist sein Zweck), daher sieht ein Capture auf `any` den marker dort auch bei ordnungsgemäß arbeitender Verschlüsselung auf der physischen NIC. Bestimme das konkrete physische Interface über `ip route get <remote-node-ip>` und verwende genau dieses. Wenn der Capture „innerhalb“ des Pfades des Pods vor der WireGuard-Verschlüsselung läuft, siehst du plaintext HTTP unabhängig davon, ob die node-to-node-Verschlüsselung aktiviert ist. Starte `tcpdump` IM HINTERGRUND, BEVOR du die HTTP-Anfrage ausführst, nicht danach. Ein Capture-Filter NUR nach `udp port 51871` schließt plaintext TCP vorab aus dem Ergebnis aus und beweist daher sein Fehlen NICHT - verwende `host <remote-node-ip>` ohne Port-Filter, damit derselbe Scope den Unterschied vorher/nachher beim Aktivieren von WireGuard tatsächlich zeigen kann. Der Checker führt seinen eigenen `tcpdump` gleichzeitig mit seiner Anfrage aus (einschließlich einer Baseline-Probe mit vorübergehender Deaktivierung von WireGuard und verifizierter anschließender Wiederherstellung) - dein artifact ist für das Lernen nützlich, aber nicht der einzige Nachweis: Wenn die Verschlüsselung zum Zeitpunkt der Prüfung tatsächlich nicht funktioniert, entdeckt das der Live-Capture des Checkers unabhängig vom Inhalt deiner Datei.
</details>

---
| **6** | **Istio PeerAuthentication STRICT** |
| :---: | :--- |
| Was wir tun | • Installiere das festgelegte Istio `1.30.4` aus dem vorbereiteten `istioctl` (das minimal profile genügt) und halte die Version der control plane fest.<br/>• Erstelle in `market` das Deployment `market-api` und den Service `market-api`: Die Anwendung lauscht auf `8080`, nenne den service port `http`. `market-api` muss auf dem gVisor-Node laufen: `nodeSelector` `lab.cks.io/role: gvisor` und toleration für dessen taint (`sandbox.runtime/gvisor=true:NoSchedule`).<br/>• Erstelle in `market` das injected Deployment `market-client` und in `default` den plaintext Pod `mesh-outside`; alle drei workloads müssen Running sein - **ohne** `PeerAuthentication` STRICT.<br/>• **Baseline:** Dieselbe outside plaintext-Anfrage an `market-api` muss HTTP 200 erhalten (mTLS ist noch nicht erforderlich); speichere diese Baseline-Antwort separat.<br/>• Wende die `PeerAuthentication` `market-strict` im Namespace `market` mit `mtls.mode: STRICT` an und wiederhole DIESELBE outside-Anfrage: Ein plaintext client ohne sidecar darf keine erfolgreiche application response erhalten, während eine in-mesh-Anfrage HTTP 200 erhalten muss.<br/>• Speichere status/headers/exit code in `artifacts/6/market-inside.txt` und `market-outside.txt` (ergänze am Ende beider Dateien eine Zeile `exit_code=<Beendigungscode von curl>`); gleiche keinen konkreten socket-error-String ab. |
| Abnahmekriterien | • Der Namespace behält `istio-injection=enabled`<br/>• `PeerAuthentication market-strict` hat `STRICT`<br/>• Innerhalb des mesh gibt es HTTP 200, und ein plaintext-Aufruf außerhalb des mesh erhält keine erfolgreiche HTTP-Antwort (curl scheitert, kein 2xx, `exit_code` in der Datei ist non-zero) - unabhängig vom genauen Fehlertext<br/>• Beide Nachweise sind gespeichert, `market-inside.txt` enthält `exit_code=0`<br/>• Ersetze den plaintext client nicht durch einen sidecar: Gerade das Fehlen des sidecar beweist die Ablehnung durch STRICT.<br/>• Der Checker wiederholt zusätzlich selbstständig VORHER/NACHHER: Er schaltet dieselbe policy vorübergehend auf `PERMISSIVE`, wiederholt dieselbe plaintext-Anfrage und verlangt 200 - das beweist, dass die vorherige Ablehnung genau durch STRICT mTLS verursacht wurde und nicht von einem unabhängigen DNS/Netzwerk-Problem<br/>• Dann stellt der Checker `STRICT` wieder her |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

Der Service port MUSS genau `http` heißen (nicht `market-api` oder etwas anderes) - Istio verwendet die named port convention, um das Protokoll zu bestimmen und den Traffic über den sidecar korrekt zu verarbeiten. `market-client` wird erstellt, NACHDEM der Namespace `istio-injection=enabled` erhalten hat - wenn das Deployment VOR diesem Label erstellt wurde, wird der sidecar nicht automatisch hinzugefügt, und du musst den Pod (nicht das Deployment) für die Injektion neu erstellen.
</details>

## Prüfung

```bash
check_result
```

Die Prüfung enthält `0 Init` und sechs obligatorische Tests. Die Tests 1-3 prüfen
`RuntimeClass`, placement und den echten Unterschied von `uname`; die Tests 4-5 prüfen WireGuard
status, die Anfrage zwischen Nodes und das Fehlen des marker im tcpdump; Test 6 führt beide
mTLS-Aufrufe erneut aus und prüft die artifacts. Wenn Istio Pods noch erstellt werden, warte auf
`kubectl get pods -n market` mit `2/2 Running` beim injected workload.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=110 make delete_cks_task
```
