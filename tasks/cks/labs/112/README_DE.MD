[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 112 - Runtime: Falco, audit-Logs und immutable root filesystem

## Ziel

In dieser CKS-Lab konfigurierst du die Kontrolle von runtime-Ereignissen auf dem Node und das audit-Logging der API der
control plane und machst dann einen workload zur Laufzeit unveränderlich. Gearbeitet wird auf einem einzigen
Node: Die `control-plane` ist zugleich der workload-Node, daher sieht Falco die Ereignisse
der Test-Pods, und der kube-apiserver liegt im static Pod manifest.

## Prüfe dich vor dem Start

<details>
<summary>1. Warum kann der audit log von Kubernetes Falco bei der runtime-Erkennung nicht ersetzen?</summary>

Der audit log protokolliert Ereignisse auf REQUEST-Ebene an den API server (wer, was und wann über `kubectl`/API angefordert hat) - das ist evidence auf Ebene der control plane. Falco dagegen beobachtet SYSTEMAUFRUFE (syscalls) innerhalb laufender Container auf dem Node - zum Beispiel das Öffnen einer shell, spawn eines Prozesses, Schreiben in eine Datei. Eine Aktion wie `docker exec`/`crictl exec` oder ein direkter Start über `ctr` auf dem Node läuft überhaupt NICHT über die Kubernetes API und gelangt nicht in den audit log, ist aber für Falco als syscall-Ereignis sichtbar.
</details>

<details>
<summary>2. Worin besteht der Unterschied zwischen den Stufen `RequestResponse` und `Metadata` der audit-policy, und warum braucht man für Secrets gerade `Metadata`?</summary>

`RequestResponse` protokolliert den vollständigen Körper der Anfrage UND der Antwort, einschließlich des Inhalts der Ressource. `Metadata` protokolliert nur Metadaten der Anfrage (wer, wann, welche Ressource, welches verb) OHNE Körper. Für `secrets` ist das kritisch: `RequestResponse` würde den Wert des Secrets selbst (base64-kodiert, aber trotzdem sensible Daten) in den audit log in Form einer lesbaren Datei auf der Platte schreiben - das schafft eine neue Leckfläche. `Metadata` liefert eine forensic-Spur ("wer dieses Secret wann gelesen hat"), ohne das Secret selbst in den Log zu kopieren.
</details>

<details>
<summary>3. Warum ist `readOnlyRootFilesystem: true` nicht gleichbedeutend mit vollständigem Schutz vor einer Kompromittierung des Containers zur Laufzeit?</summary>

`readOnlyRootFilesystem` blockiert das Schreiben in das Root-Dateisystem des Containers, was einen Angreifer daran hindert, Binärdateien der Anwendung zu modifizieren oder persistence auf der Platte des Containers zu installieren. Aber das hindert NICHT: (a) beschreibbare volumes/emptyDir, die der Pod selbst explizit mountet (zum Beispiel `/tmp`), (b) die Ausführung von Aktionen im Speicher des Prozesses (RCE ohne Schreiben auf die Platte), (c) Netzwerkangriffe von innerhalb des Containers, (d) das Lesen bereits gemounteter Secrets/ConfigMaps. Die Unveränderlichkeit von rootfs ist eine Schutzschicht und keine vollständige Isolation.
</details>

## Bezug zum Kurs

- [Kapitel 29. Verhaltensanalyse zur Laufzeit: Falco](../../course/29/de.md)
- [Kapitel 30. Erkennung von Bedrohungen und Untersuchung von Angriffsphasen](../../course/30/de.md)
- [Kapitel 31. Unveränderlichkeit von Containern zur Laufzeit](../../course/31/de.md)
- [Kapitel 32. Audit-Logs von Kubernetes](../../course/32/de.md)
- [Kapitel 26. Registries, Signatur und Validierung von Artefakten](../../course/26/de.md) - Aufgabe 9 verbindet die admission-Kontrolle der registry allowlist mit der runtime-Erkennung der Umgehung (nicht signature verification - die prüft Lab 111).

## Infrastruktur

| Komponente | Zweck |
|---|---|
| `k8s-1` | Ein-Node-Kubernetes `1.36.0`, containerd und Calico; der Node-Name ist `control-plane` |
| `worker` | Arbeitsmaschine mit `kubectl`, `check_result` und SSH-Zugriff `ssh control-plane` |
| `runtime-112` | vorbereiteter Namespace; darin ist bereits das Secret `audit-secret` |

Der Bootstrap installiert Falco absichtlich **nicht** und aktiviert den audit backend **nicht**. Er
bereitet nur das Verzeichnis `/etc/kubernetes/audit`, das Log-Verzeichnis
`/var/log/kubernetes/audit` und ein Secret für eine kontrollierte API-Anfrage vor. Ändere nicht CNI,
Cluster-Version, Secret oder Kubernetes-Manifeste außerhalb von Aufgabe 4.

## Bereitstellung

```bash
TASK=112 make run_cks_task
```

Auf der Arbeitsmaschine:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
ssh control-plane 'sudo -n true'
```

## Wie man mit dem Node arbeitet

Öffne zwei Terminals: **Terminal 1** - `ssh control-plane`, dann `sudo -i` (Operationen am Node:
Falco, audit, `crictl`, `/proc`), **Terminal 2** - Arbeitsmaschine (`kubectl`, `scp`, Prüfungen).
Artifacts, die auf dem Node gewonnen wurden, speichere in einer Datei auf der `control-plane` und kopiere sie auf die Arbeitsmaschine mit dem
Befehl `scp` nach `/var/work/tests/artifacts/<Nummer der Aufgabe>/`.

## Aufgaben

Vor dem containment ist es nützlich, den blast radius gedanklich einzuschätzen: ob der ServiceAccount
des kompromittierten Pods Secrets lesen, workloads erstellen oder andere
Namespaces erreichen kann. Das lässt sich als zusätzlicher Schritt schnell mit `kubectl auth can-i` im Namen des
ServiceAccount `falco-shell` prüfen und sollte man auch tun; er ist nicht obligatorisch, beeinflusst die
Abnahmekriterien nicht und wird nicht getestet.

---
| **1** | **Falco auf dem workload-Node installieren und starten** |
| :---: | :--- |
| Was wir tun | • Installiere auf der `control-plane` das Falco-Paket aus dem offiziellen Falco-Repository und starte den Dienst.<br/>• Verwende die modern eBPF engine; installiere kein kernel module von Hand.<br/>• Aktiviere den Dienst über systemd. |
| Abnahmekriterien | • `falco --version` wird ausgeführt<br/>• `systemctl is-active falco` gibt `active` zurück<br/>• Die Konfiguration enthält `engine.kind: modern_ebpf` |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

Die modern eBPF engine wird über `engine.kind: modern_ebpf` in `/etc/falco/falco.yaml` konfiguriert (nicht über einen separaten kernel module driver, der für die legacy engine nötig ist) - wenn Falco nach der Installation nicht startet oder beim Start abstürzt, prüfe `journalctl -u falco-modern-bpf` (das Paket installiert die unit `falco-modern-bpf.service`, und `falco.service` ist nur ein alias darauf: `systemctl status/restart falco` funktioniert, aber `journalctl -u falco` ist leer) auf Fehler beim Laden des eBPF program, was auf einen inkompatiblen Kernel hindeuten kann.
</details>

---
| **2** | **Das Standardereignis einer shell im Container festhalten** |
| :---: | :--- |
| Was wir tun | • Erstelle in `runtime-112` den Pod `falco-shell` aus `busybox:1.36`, lasse ihn Running (`sleep 3600`) und aktiviere `stdin: true`, `tty: true`.<br/>• Öffne darin eine interaktive `/bin/sh` und warte auf die Falco-Regel **Terminal shell in container**.<br/>• Speichere die passende Zeile aus dem Falco-journal (sie wird auf der `control-plane` gelesen) in einer Datei auf dem Node und kopiere sie per `scp` nach `/var/work/tests/artifacts/2/falco-shell.log` auf die Arbeitsmaschine. |
| Abnahmekriterien | • Der Pod `falco-shell` ist Running<br/>• Das artifact ist nicht leer und enthält die Alert-Zeile `A shell was spawned in a container with an attached terminal` (so gibt die Regel **Terminal shell in container** das Ereignis in der Textausgabe von Falco 0.45 aus; der Name der Regel steht nur in der JSON-Ausgabe)<br/>• Das Ereignis muss von Falco empfangen und nicht von Hand geschrieben worden sein |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Einfach einen Pod mit `stdin: true, tty: true` zu erstellen reicht nicht - du musst TATSÄCHLICH eine interaktive Sitzung öffnen (`kubectl exec -it falco-shell -- /bin/sh`), damit Falco gerade den spawn des shell-Prozesses im Container festhält. Suche das Ereignis über `journalctl -u falco-modern-bpf --no-pager | grep "shell was spawned"` auf der `control-plane` (über SSH vom worker) und versuche nicht, die Zeile von Hand in die Datei zu schreiben - der Test erwartet den echten timestamp/das Format aus dem journal.
</details>

---
| **3** | **Eine custom Falco rule hinzufügen und auslösen** |
| :---: | :--- |
| Was wir tun | • Füge auf der `control-plane` in `/etc/falco/falco_rules.local.yaml` eine Regel mit dem Namen `CKS112 Custom Shell Marker` hinzu.<br/>• Sie muss einen spawned process im Container erfassen, dessen `proc.cmdline` `CKS112_CUSTOM_EVENT` enthält.<br/>• Sie muss die exakte Phrase `CKS112 custom shell marker` zusammen mit `container=%container.id`, `pid=%proc.pid`, `ppid=%proc.ppid`, `user=%user.name` und `command=%proc.cmdline` ausgeben.<br/>• Starte Falco neu.<br/>• Führe in `falco-shell` einen beliebigen kurzen Befehl aus, in dessen Kommandozeile der marker steht, zum Beispiel: `kubectl exec -n runtime-112 falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT'`.<br/>• Finde im Falco-journal auf der `control-plane` die Zeile dieser Auslösung (darin steht `CKS112 custom shell marker`), speichere sie in einer Datei auf dem Node und kopiere sie per `scp` nach `/var/work/tests/artifacts/3/falco-custom.log`. Die Zeile muss eine echte journal-Zeile sein, eine von Hand geschriebene wird nicht akzeptiert. |
| Abnahmekriterien | • Die lokale rules-Datei existiert, enthält den Namen der Regel, die Bedingung des markers und Identifikatoren für die Untersuchung<br/>• Der Falco-Dienst ist aktiv<br/>• Das echte journal-artifact enthält marker, container ID und PID |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Die custom rule in `falco_rules.local.yaml` erfordert eine `condition`, die `spawned_process` (oder `evt.type=execve`) zusammen mit `proc.cmdline contains "CKS112_CUSTOM_EVENT"` verwendet - ohne die Basisbedingung zum Ereignistyp löst die Regel möglicherweise überhaupt nicht aus oder löst bei falschen Ereignissen aus. Führe nach dem Bearbeiten der Datei `systemctl restart falco` aus, um die Anwendung der Regeln deterministisch zu bestätigen. In aktuellem Falco ist bei aktiviertem `watch_config_files: true` auch ein automatisches reload möglich, aber in dieser Lab wird ein expliziter restart verwendet.
</details>

---
| **4** | **Audit-Logging aktivieren: RequestResponse für ConfigMap, Metadata für Secret** |
| :---: | :--- |
| Was wir tun | • Erstelle auf der `control-plane` `/etc/kubernetes/audit/policy.yaml`. Die policy muss `RequestResponse` **nur im Namespace `runtime-112`** für die core resource `configmaps` protokollieren (ein kontrolliertes forensic-Beispiel an einer nicht sensiblen Ressource).<br/>• Verwende für die core resource `secrets` nur `Metadata`, **damit der Körper des Secrets nicht ins Journal gelangt**.<br/>• Reduziere das Rauschen tatsächlich durch explizite `None`-Regeln für high-volume/low-risk Traffic und `omitStages: [RequestReceived]`.<br/>• Beende die policy mit einem sicheren catch-all `Metadata` als *fallback logging* und nicht als Rauschunterdrückung.<br/>• Füge im static manifest `/etc/kubernetes/manifests/kube-apiserver.yaml` `--audit-policy-file=/etc/kubernetes/audit/policy.yaml`, `--audit-log-path=/var/log/kubernetes/audit/audit.log` und Rotation (`--audit-log-maxage`, `--audit-log-maxbackup`, `--audit-log-maxsize`) hinzu.<br/>• Füge die notwendigen hostPath volume/volumeMount für das policy-Verzeichnis und das Log-Verzeichnis hinzu. Warte auf die Wiederherstellung der API.<br/>• Erstelle die ConfigMap `audit-config` in `runtime-112`, lies sie (`kubectl get configmap audit-config -n runtime-112 -o json`) und speichere das RequestResponse event in `/var/work/tests/artifacts/4/configmap-request-response.json`.<br/>• Lies dann `kubectl get secret audit-secret -n runtime-112 -o json` und speichere sein Metadata event in `/var/work/tests/artifacts/4/secret-metadata.json`. Die Events stammen aus dem audit log auf der `control-plane`: Speichere sie auf dem Node und kopiere sie per `scp`. |
| Abnahmekriterien | • Kube-apiserver ist healthy<br/>• Das static manifest enthält beide audit-Flags und mounts<br/>• Die policy setzt `RequestResponse` für `configmaps` und `Metadata` für `secrets`<br/>• In `/var/work/tests/artifacts/4/configmap-request-response.json` - das RequestResponse event für die ConfigMap<br/>• In `/var/work/tests/artifacts/4/secret-metadata.json` - ein Secret-Ereignis der Stufe `Metadata` **ohne die Felder `requestObject`/`responseObject`** (der Körper des Secrets ist nicht protokolliert) |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

Die Reihenfolge der Regeln in der audit policy ist wichtig: Kubernetes wendet die ERSTE passende Regel von oben nach unten an, daher muss die spezifische Regel für `configmaps`/`secrets` in `runtime-112` VOR dem allgemeinen catch-all `Metadata` am Ende der Datei stehen - steht das catch-all an erster Stelle, "fängt" es alle Anfragen vor den spezifischen Regeln ab. Nach dem Bearbeiten des static manifest übernimmt das kubelet die Änderungen selbst (kein `kubectl apply`/restart nötig) - aber warte, bis `kubectl get --raw=/readyz` wieder Erfolg zurückgibt, bevor du fortfährst.
</details>

---
| **5** | **Einen Pod mit schreibgeschütztem root filesystem erstellen** |
| :---: | :--- |
| Was wir tun | • Erstelle in `runtime-112` den Pod `immutable-app`: Container `app`, Image `busybox:1.36`, `sleep 3600`.<br/>• Aktiviere am Container `securityContext.readOnlyRootFilesystem: true`.<br/>• Erstelle ein `emptyDir` `writable-tmp` und mounte es nach `/tmp` ohne `readOnly: true`. Verwende kein `hostPath`.<br/>• Belege, dass `touch /cks-112-write-denied` fehlschlägt und `touch /tmp/allowed` erfolgreich ist; speichere das Ergebnis der Ablehnung in `/var/work/tests/artifacts/5/rootfs-write-denied.log`. |
| Abnahmekriterien | • Der Pod ist Running<br/>• Das root filesystem ist read-only<br/>• `/tmp` - ein beschreibbares `emptyDir`<br/>• Im Pod gibt es kein `hostPath`<br/>• Das Schreiben in rootfs wird blockiert, in `/tmp` ist es erlaubt<br/>• Das artifact ist nicht leer |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

Speichere gerade die FEHLERAUSGABE des Befehls `touch /cks-112-write-denied` (`Read-only file system` in stderr) und nicht nur die Tatsache, dass der Befehl mit einem Code ungleich null endete - der Test prüft den Inhalt des Logs. Verwechsle nicht `emptyDir` (ephemer, lebt mit dem Pod) mit `hostPath` (persistent auf dem Node, in dieser Aufgabe verboten) - beide "lösen" technisch die Aufgabe eines beschreibbaren Verzeichnisses, aber hier ist nur das erste erlaubt.
</details>

---
| **6** | **Minimale containment-Kette vom Alert bis zur Isolation** |
| :---: | :--- |
| Was wir tun | • Starte nach dem Aktivieren des audit backend in `falco-shell` einen kontrollierten langlebigen Prozess, in dessen Kommandozeile `CKS112_CUSTOM_EVENT` steht, zum Beispiel: `kubectl exec -n runtime-112 falco-shell -- sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT &`. Der Prozess lebt 10 Minuten: Solange er lebt, kann man sein `/proc/<PID>` abnehmen.<br/>• **Beginne die Untersuchung mit dem neuen Falco alert** und nicht mit dem Pod manifest. Extrahiere aus dem alert die short container ID und die host PID.<br/>• Ordne auf der `control-plane` über `crictl ps/inspect/inspectp` container → Pod sandbox → Namespace/Pod zu; bestimme den Node über die Kubernetes API. Speichere `crictl inspect` und `inspectp`.<br/>• Speichere, solange der Prozess lebt, `/proc/<PID>/status`, `cmdline`, `cgroup` und den Baum PID/PPID/user.<br/>• Finde im audit log das event `pods/exec` für `runtime-112/falco-shell` und speichere es ohne request/response body.<br/>• Klassifiziere die Phase als `Execution`, die Technik als `Container Administration Command`, erstelle `evidence-summary.txt`. Auf der `control-plane` gewonnene Dateien kopiere per `scp` nach `/var/work/tests/artifacts/6/`.<br/>• Wende dann die default-deny ingress+egress `NetworkPolicy` `incident-quarantine` an, lösche den kompromittierten Pod und speichere die negative Prüfung: Ein erneutes `kubectl exec` geht nicht durch.<br/>• Das ist die minimale containment-Kette: credential revocation/rotation und vollständige remediation erfordern einen separaten incident-response-Prozess. |
| Abnahmekriterien | • In `/var/work/tests/artifacts/6/` gibt es einen echten Falco alert, CRI inspect/inspectp, drei `/proc`-artifacts, process lineage, ein Metadata audit event für `pods/exec`, die abschließende Zusammenfassung und das Ergebnis des containment<br/>• Der Pod `falco-shell` fehlt<br/>• `incident-quarantine` wählt alle Pods aus und schließt ingress+egress<br/>• Ein erneutes exec hat einen non-zero exit code |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

Die strenge Reihenfolge der Aktionen ist für die Glaubwürdigkeit der Untersuchung wichtig: Beginne mit dem Falco alert (das ist es, was incident response tatsächlich auslösen würde) und NICHT mit dem bereits bekannten Pod-Namen - sonst bestätigst du nur, was du schon weißt, und führst keine echte correlation durch. Sammle die Artefakte `/proc/<PID>/*`, solange der Prozess LEBT - sobald du den Pod löschst (letzter Schritt), verschwindet `/proc` für diese PID für immer, daher ist die Reihenfolge "erst evidence, dann containment" bei Verwechslung nicht umkehrbar.
</details>

---
| **7** | **Upstream-Falco-macro überschreiben, Pod/Namespace-evidence in den output aufnehmen, JSON in Datei** |
| :---: | :--- |
| Was wir tun | • Die Standardregel von Falco **Terminal shell in container** würde auch bei einem legitimen CI/CD-Werkzeug auslösen, das regulär eine shell im Container öffnet (zum Beispiel `kubectl debug` oder ein sidecar mit Wartungsskript). Überschreibe statt die Regel selbst zu bearbeiten das upstream-macro, das gerade für diese Regel vorgesehen ist.<br/>• Überschreibe in `/etc/falco/falco_rules.local.yaml` `user_expected_terminal_shell_in_container_conditions` (standardmäßig `(never_true)` in der Regel **Terminal shell in container** selbst - nicht zu verwechseln mit `user_shell_container_exclusions`, das zu einer separaten Regel **Run shell untrusted**/"Shell spawned by untrusted binary" gehört), damit er einen konkreten Pod `ci-runner` im Namespace `runtime-112` zulässt.<br/>• Verwende `k8s.pod.name` und `k8s.ns.name` und nicht `container.name`: `container.name` ist der Name des **Containers** (in dieser Aufgabe `app`) und nicht des Pods, und eine Übereinstimmung nach dem Namen des Containers ergibt fast immer eine falsche oder zu breite allowlist.<br/>• Der Standard-output der Regel **Terminal shell in container** enthält nicht `k8s.pod.name`/`k8s.ns.name` (prüfe das upstream `falco_rules.yaml` selbst - dort sind sie nicht); ohne diese Felder ist die correlation eines konkreten alert mit einem konkreten Pod nicht zuverlässig möglich. Füge über denselben `override`-Mechanismus (`output: append`) am Ende des output der Regel `k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name` hinzu.<br/>• Erstelle in `runtime-112` den Pod `ci-runner` aus `busybox:1.36` mit interaktiver `sh` (`stdin: true`, `tty: true`) und bestätige, dass für ihn **kein** alert `Terminal shell in container` erzeugt wird, während für `immutable-app` aus Aufgabe 5 (ohne Ausnahme) der alert weiter auslöst.<br/>• Aktiviere separat über `/etc/falco/config.d/cks112-output.yaml` `json_output: true` und `file_output.enabled: true` mit `file_output.filename: /var/log/falco/events.log`; starte Falco neu.<br/>• Bestätige über strukturiertes JSON (`jq .output_fields`) und nicht über ein Text-`grep`, dass der aufgezeichnete alert für `immutable-app` `k8s.pod.name == "immutable-app"` und `k8s.ns.name == "runtime-112"` enthält. |
| Abnahmekriterien | • `falco_rules.local.yaml` enthält `macro: user_expected_terminal_shell_in_container_conditions` mit einer Bedingung, die auf `k8s.pod.name = "ci-runner"` und `k8s.ns.name = "runtime-112"` verweist (nicht `never_true`, nicht `container.name`), und ein separates `override: output: append`, das `%k8s.ns.name`/`%k8s.pod.name` zur Regel `Terminal shell in container` hinzufügt<br/>• Eine shell in `ci-runner` erzeugt während der Beobachtungszeit keinen alert, und eine shell in `immutable-app` erzeugt einen<br/>• `config.d/cks112-output.yaml` enthält `json_output: true` und `file_output: {enabled: true, filename: /var/log/falco/events.log}`<br/>• `/var/log/falco/events.log` enthält eine gültige JSON-Zeile mit `rule == "Terminal shell in container"` und `output_fields["k8s.pod.name"] == "immutable-app"`, `output_fields["k8s.ns.name"] == "runtime-112"`<br/>• Der Pod `falco-shell` aus Aufgabe 2 ist zu diesem Zeitpunkt bereits gelöscht (Aufgabe 6) und wird hier nicht verwendet |

<details>
<summary>💡 Hinweis zu Aufgabe 7</summary>

Zwei verschiedene override-Mechanismen verwechselt man leicht: Das `macro`-override ändert die BEDINGUNG des Auslösens der Regel (wen man ausnimmt), und das `output`-override mit `append` ändert nur das FORMAT der Ausgabe (was gedruckt wird) - für diese Aufgabe werden BEIDE gebraucht, in separaten Blöcken `- macro: ...` und `- rule: ... / override: / output: append`. Prüfe buchstäblich die Schreibweise von `user_expected_terminal_shell_in_container_conditions` - Falco hat mehrere im Namen ähnliche macros für verschiedene Regeln (das in der Aufgabe erwähnte `user_shell_container_exclusions` gehört zu einer ANDEREN Regel), die Verwendung des falschen macro erzeugt keinen Ladefehler, aber die allowlist funktioniert dann einfach nicht.
</details>

---
| **8** | **Audit webhook backend anstelle von/zusammen mit der lokalen Datei** |
| :---: | :--- |
| Was wir tun | • Verwende den vom bootstrap bereits vorbereiteten HTTP-Empfänger `audit-receiver` (Deployment + Service auf Port `8080`, Image `ghcr.io/mendhak/http-https-echo:40`), der audit-Ereignisse empfängt.<br/>• Erstelle auf der `control-plane` `/etc/kubernetes/audit/webhook-config.yaml` im kubeconfig-Format mit `server: http://<ClusterIP Empfänger>:8080/audit` (für die Lab ist HTTP zulässig; in production erfordert der webhook HTTPS und ein client certificate - siehe Kapitel 32).<br/>• Füge im static manifest `kube-apiserver.yaml` `--audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml` und `--audit-webhook-batch-max-wait=1s` hinzu (verringerte batch-Verzögerung für die Beobachtbarkeit in der Lab) und behalte dabei die bereits konfigurierten `--audit-policy-file` und `--audit-log-path` aus Aufgabe 4 - der webhook ergänzt den lokalen file backend und ersetzt ihn nicht.<br/>• Führe nach der Wiederherstellung der API eine beliebige auditierte Anfrage aus (zum Beispiel `kubectl get configmap audit-config -n runtime-112`) und bestätige in den Logs von `audit-receiver`, dass das Ereignis zugestellt wurde. |
| Abnahmekriterien | • `audit-receiver` ist Running mit Service<br/>• `webhook-config.yaml` ist eine gültige kubeconfig mit `server` auf diesen Service<br/>• Das static manifest des kube-apiserver enthält `--audit-webhook-config-file` und `--audit-webhook-batch-max-wait` sowie die erhaltenen Flags des file backend aus Aufgabe 4<br/>• Kube-apiserver ist nach der Änderung healthy<br/>• Die Logs von `audit-receiver` enthalten mindestens ein JSON audit event des Anfragekörpers mit dem Feld `objectRef` |

<details>
<summary>💡 Hinweis zu Aufgabe 8</summary>

`webhook-config.yaml` hat das KUBECONFIG-FORMAT (mit `clusters`/`users`/`contexts`) und ist kein beliebiges YAML mit einem Feld `server` - wenn die Struktur der Datei nicht dem kubeconfig schema entspricht, kann kube-apiserver sie nicht parsen und startet überhaupt nicht. Vergiss nicht, dass der webhook den file backend ERGÄNZT und nicht ersetzt - wenn du die Flags `--audit-policy-file`/`--audit-log-path` aus Aufgabe 4 entfernst, bestehen die Tests von Aufgabe 4 nicht mehr.
</details>

---
| **9** | **Integrationsaufgabe: admission allowlist direkt über containerd umgehen und den Versuch über Falco erkennen** |
| :---: | :--- |
| Was wir tun | • Diese Aufgabe verbindet Supply Chain Security (siehe [Lab 111](../111/README_DE.MD) und [Kapitel 26](../../course/26/de.md)) mit Runtime Security dieser Lab. **Wichtiger Unterschied zu Lab 111**: Dort prüft die `ImageValidatingPolicy` die **kryptografische Signatur** (Cosign). Hier prüft die policy nur die **registry/repository allowlist** (permitted registry, ohne signature/attestor) - eine einfachere, aber ebenso echte admission control mit demselben Prinzip: Sie funktioniert nur auf dem API admission path und sieht keine Aktionen, die sich nicht an sie wenden.<br/>• Die controlled abuse fixture dieser Aufgabe ist eine lab-owned lokale Registry und nicht das öffentliche Docker Hub: Der bootstrap hat auf der `control-plane` bereits drei Images mit unterschiedlichen digests im lokalen containerd content store vorbereitet und ihre Namen in `/etc/cks112/registry.env` gespeichert (`CKS112_REGISTRY=cks112.local:5000`, `CKS112_TRUSTED_REPO=cks112/trusted`, `CKS112_UNTRUSTED_REPO=cks112/untrusted`, `CKS112_TRUSTED_IMAGE`, `CKS112_UNTRUSTED_IMAGE`, `CKS112_PREFIX_IMAGE`) - binde (`source`) diese Datei zu Beginn der Aufgabe ein und verwende nur diese Werte.<br/>• Installiere Kyverno (`install-kyverno`, wie in Lab 111) und erstelle die `ValidatingPolicy` `require-trusted-registry-runtime-112` (native CEL, `apiVersion: policies.kyverno.io/v1`), die über `image(c.image).registry()`/`.repository()` (Kyverno CEL Image library) jeden Pod in `runtime-112` **ablehnt**, dessen Image nicht exakt `registry: $CKS112_REGISTRY` und `repository: $CKS112_TRUSTED_REPO` entspricht - nicht `startsWith`, um ähnliche Namen wie `cks112/trusted-evil` nicht durchzulassen. Gib der policy eine eindeutige denial-Meldung, zum Beispiel `CKS112_TRUSTED_REPO_POLICY: only $CKS112_TRUSTED_IMAGE is allowed`.<br/>• Bestätige diesen Pfad: Wende den Pod `blocked-attempt` mit dem Image `$CKS112_UNTRUSTED_IMAGE` (nicht in der allowlist) an und speichere die Ausgabe des admission denial in `9/admission-deny.txt`.<br/>• Modelliere dann auf der `control-plane` über `cks112-run $CKS112_UNTRUSTED_IMAGE cks112-bypass-1 'echo CKS112_CTR_BYPASS; sleep 5'` (das Image ist seit dem bootstrap lokal vorhanden, ein erneuter pull ist nicht nötig) den Pfad, der nicht über den API server läuft und für den admission controller nicht sichtbar ist (der helper startet über CRI selbst im detached-Modus; verwende eine eindeutige ID für die erneute Prüfung und lösche den Container danach über `cks112-rm <id>`).<br/>• **Bestimme, bevor du die Falco-Regel schreibst, den REALEN observed-Wert des Feldes `%container.image.repository` für das vertrauenswürdige `$CKS112_TRUSTED_IMAGE` auf deinem containerd/Falco-Stack** - dieses Feld wird in verschiedenen Versionen unterschiedlich gebildet (möglicherweise mit dem Hostnamen der Registry, möglicherweise ohne), nimm das Format daher nicht vorab an: Gib mit einer temporären Regel mit sicherem marker den Wert ins Log aus und speichere ihn als `$TRUSTED_REPO` (speichere die evidence in `9/observed-trusted-repo.txt`).<br/>• Füge in `falco_rules.local.yaml` die custom rule `CKS112 Runtime Bypass of Admission` hinzu, die einen spawned process mit `proc.cmdline`, der `CKS112_CTR_BYPASS` enthält, **und** `container.image.repository`, das nicht in der allowlist liegt, erfasst und `container.image.repository` zusammen mit Prozess-Identifikatoren ausgibt. Verwende den **exakten** Vergleich `container.image.repository != "$TRUSTED_REPO"` mit dem beobachteten Wert (keine `startswith`/Präfix-Prüfung: `not container.image.repository startswith "$TRUSTED_REPO"` würde ein Repository wie `<observed-value>-evil` durchlassen, also nicht bemerken, weil sein Name einfach mit dem erlaubten Teilstring beginnt - derselbe Fehler, den die obige Kyverno policy durch `==` statt `startsWith` vermeidet).<br/>• Prüfe zusätzlich beide kontrollierten Fälle: Das vertrauenswürdige `$CKS112_TRUSTED_IMAGE` darf die Regel NICHT auslösen (nur nach dem Merkmal repository - der marker `CKS112_CTR_BYPASS` selbst kann dabei trotzdem separat geprüft werden), und ein Image mit dem repository `<observed-value>-evil` MUSS die Regel auslösen - gerade das belegt, dass der Vergleich exakt und nicht prefix-basiert ist.<br/>• Speichere die Auslösung in `9/falco-bypass-attempt.log` (auf der `control-plane` gewonnene Dateien werden per `scp` nach `/var/work/tests/artifacts/9/` kopiert). |
| Abnahmekriterien | • Kyverno ist installiert und Available<br/>• Die `ValidatingPolicy require-trusted-registry-runtime-112` existiert mit `apiVersion: policies.kyverno.io/v1`, validation action `Deny`, verwendet `image(...).registry()`/`.repository()` für einen exakten (nicht `startsWith`) Vergleich, und ihre `message`/`messageExpression` enthält den eindeutigen Marker `CKS112_TRUSTED_REPO_POLICY`<br/>• Der Pod `blocked-attempt` wurde nicht erstellt (admission denial), `9/admission-deny.txt` enthält gerade diesen Marker (nicht irgendeinen generischen admission-Fehler)<br/>• `9/observed-trusted-repo.txt` enthält den tatsächlich beobachteten Wert von `%container.image.repository` für das vertrauenswürdige Image<br/>• `falco_rules.local.yaml` enthält die Regel `CKS112 Runtime Bypass of Admission` mit einer **exakten** (nicht `startswith`/Präfix) Bedingung für `container.image.repository`, die gerade diesen beobachteten Wert verwendet<br/>• `9/falco-bypass-attempt.log` enthält eine nicht leere Auslösung mit `CKS112_CTR_BYPASS` und einem image repository außerhalb der allowlist (Suffix `-evil` am beobachteten Wert) - dieses Repository ist gezielt als prefix-trap gewählt: Es muss erkannt werden, obwohl es mit dem erlaubten String beginnt |

<details>
<summary>💡 Hinweis zu Aufgabe 9</summary>

Der Kerngedanke der Aufgabe: `cks112-run` (ein Wrapper um `crictl`, der den Container direkt über CRI erstellt) wendet sich an containerd und umgeht kube-apiserver und damit JEDEN admission controller (auch Kyverno) - das ist eine Demonstration, dass admission control nur den Pfad über die Kubernetes API schützt und nicht den gesamten Node. Deine Falco-Regel muss über `and` in einer `condition` prüfen: einen Container-Prozess (`container.id != host` - der Startbefehl auf dem Host enthält ebenfalls den marker), den marker `CKS112_CTR_BYPASS` UND ein repository außerhalb der allowlist - wenn du nur den marker prüfst, löst die Regel sogar bei legitimen Testprozessen mit ähnlichem cmdline aus.
</details>

---
| **10** | **Zugriff auf `/dev/mem` über eine andere Klasse von Falco-Bedingung erkennen und den workload stoppen** |
| :---: | :--- |
| Was wir tun | • Die Aufgaben 3, 7 und 9 verwendeten eine Bedingung auf `spawned_process`/`proc.cmdline` - Erkennung anhand des Prozessstarts. Hier wird eine grundsätzlich andere Klasse von Falco condition gebraucht: Erkennung anhand des **Öffnens einer Datei/eines Geräts**.<br/>• In `runtime-112` gibt es bereits das Deployment `mem-scanner` (2 Replicas), dessen beide Replicas periodisch `/dev/mem` innerhalb des Containers öffnen - ein gewöhnlicher application workload hat keinen Grund dafür, und ein solcher Zugriff ist ein starker Indikator für eine gefährliche Konfiguration oder einen Versuch, die Isolation des Containers zu umgehen. Der Pfad `/dev/mem` innerhalb des Containers ist eine synthetic safe fixture (das backing device ist tatsächlich das host `/dev/null` und nicht der reale physische Speicher des Hosts); für Falco spielt das keine Rolle - die Regel erkennt den Systemaufruf `open`/`openat`/`openat2` selbst anhand des Dateinamens `fd.name = /dev/mem`, unabhängig davon, welches Gerät tatsächlich dahintersteht.<br/>• Füge auf der `control-plane` in `/etc/falco/falco_rules.local.yaml` die Regel `CKS112 Container access to /dev/mem` mit der Bedingung `evt.type in (open, openat, openat2) and fd.name = /dev/mem and container.id != host` hinzu, priority `CRITICAL`, der output muss `container_id=%container.id`, `k8s_pod=%k8s.pod.name` und `k8s_ns=%k8s.ns.name` enthalten. Starte Falco neu.<br/>• Finde die Auslösung im journal und bestimme anhand davon den **konkreten** Pod (rate nicht anhand des Namens - verwende `k8s_pod` aus dem alert selbst); bestimme anhand des konkreten alert, welche Replica das festgehaltene Ereignis erzeugt hat. Speichere die alert-Zeile auf dem Node und kopiere sie per `scp` nach `/var/work/tests/artifacts/10/falco-devmem.log`.<br/>• Führe `kubectl scale deployment mem-scanner -n runtime-112 --replicas=0` aus und speichere den resultierenden Zustand (`kubectl get deployment mem-scanner -n runtime-112 -o json`) in `/var/work/tests/artifacts/10/scaled-down.json`. |
| Abnahmekriterien | • `falco_rules.local.yaml` enthält eine Regel mit dem Namen `CKS112 Container access to /dev/mem`, einer Bedingung auf `fd.name = /dev/mem` (nicht auf `proc.cmdline`/spawned_process) und `container.id != host`, priority `CRITICAL`<br/>• Falco ist aktiv<br/>• `10/detected-pod.json` hält den echten Pod und die owner chain vor dem containment fest<br/>• `10/falco-devmem.log` - eine echte Zeile aus dem journal mit dieser Regel und einem nicht leeren `k8s_pod`<br/>• Das Deployment `mem-scanner` ist auf `replicas: 0` skaliert<br/>• `10/scaled-down.json` bestätigt `spec.replicas == 0` |

<details>
<summary>💡 Hinweis zu Aufgabe 10</summary>

Verwechsle diese Bedingung nicht mit den Aufgaben 3/7/9 - dort erfasst `spawned_process`/`execve` den START eines Prozesses anhand der Kommandozeile, und hier erfasst `open`/`openat`/`openat2` das ÖFFNEN einer konkreten Datei/eines Geräts, unabhängig davon, welcher Prozess das tut und mit welchen Argumenten der Kommandozeile. `container.id != host` schneidet legitime Systemprozesse auf dem Node selbst (nicht im Container) heraus, die aus anderen Gründen Zugriff auf `/dev/mem` brauchen können. Skaliere das Deployment nicht herunter, bevor du den alert gefunden hast - zuerst die Erkennung über Falco, dann das containment, sonst belegst du nicht, dass du den Pod gerade über das Monitoring gefunden hast und nicht, indem du den Pod vorab nach Namen ausgewählt hast. Hole zuerst den Falco alert und bestimme nur aus seinem `k8s_pod` die konkrete Replica, die dieses Ereignis erzeugt hat.
</details>

## Prüfung

```bash
check_result
```

Die Prüfung enthält Init und zehn unabhängige Tests. Sie prüft den Zustand von Falco und
kube-apiserver per SSH, API-Objekte, CRI/`/proc` evidence, audit correlation, containment
und die tatsächliche Schreibverweigerung in rootfs. Starte nach dem
Ändern des static Pod manifest das kubelet nicht ohne Notwendigkeit neu: Das kubelet bemerkt die Änderung
selbst. Wenn die API vorübergehend nicht verfügbar ist, warte auf `kubectl get --raw=/readyz`.
Speichere ein backup der Datei `kube-apiserver.yaml` nur außerhalb von `/etc/kubernetes/manifests`: Das kubelet liest jede Datei ohne führenden Punkt in diesem Verzeichnis.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=112 make delete_cks_task
```
