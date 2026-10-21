[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 106 - AppArmor und seccomp: node-local policy und nachprüfbare Ablehnungen

## Ziel

In dieser CKS-Lab wendest du zwei unabhängige Mechanismen zum Schutz des Container-Prozesses auf
Ebene des Linux-Kernels an. Zuerst überführst du ein vorab geliefertes **AppArmor**-Profil von
`complain` nach `enforce`, weist es einem Pod über das moderne Feld
`securityContext.appArmorProfile` zu und belegst die Ablehnung des Schreibens. Dann weist du die sichere
Baseline `RuntimeDefault` und ein custom **seccomp Localhost**-Profil zu, das den
Systemaufruf `unshare(2)` blockiert.

Das ist die Fortsetzung des grundlegenden `SecurityContext` aus der CKA-Lab 106: Hier reicht es nicht, das
YAML zu schreiben. Localhost-Profile leben auf dem Kubernetes-Node, daher musst du den Node, das
Placement des Pods und das tatsächliche Verhalten des Prozesses prüfen.

## Threat model

Nehmen wir RCE im Container an. Die Frage nach dem compromise lautet nicht „konnte der Angreifer eine shell erhalten“, sondern „was kann diese shell als Nächstes tun“ und wie groß ihr blast radius ist.

AppArmor in den Aufgaben 1–2 begrenzt Objekte und Operationen: Das Profil wird in enforce überführt, und dann wird die Ablehnung des Schreibens belegt. So erhält ein bereits kompromittierter Prozess keine unbegrenzte Aktion nur deshalb, weil er in einem Container läuft.

seccomp in den Aufgaben 3–5 begrenzt den verfügbaren Systemaufruf: Zuerst wird die Baseline angewendet, dann das custom profile, und dann wird die tatsächliche Ablehnung von `unshare(2)` geprüft. Aufgabe 5 enthält bereits einen negative control über den Pod `sysadmin-control`: Bei derselben capability ohne seccomp filter geht der Aufruf durch, daher zeigt der Vergleich gerade die Grenze nach dem compromise.

## Prüfe dich vor dem Start

<details>
<summary>1. Wie unterscheidet sich `complain` von `enforce` in AppArmor, und warum darf `complain` nicht als Beleg für Schutz gezeigt werden?</summary>

Im Modus `complain` protokolliert AppArmor Verletzungen des Profils nur, blockiert sie aber NICHT - eine Operation, die verboten sein sollte, wird trotzdem ausgeführt, es erscheint lediglich ein Eintrag im Journal. In `enforce` wird die Operation tatsächlich blockiert. Aufgabe 1 verlangt ausdrücklich, das Profil in `enforce` zu überführen, weil die Demonstration "hier ist die Verletzung im Log" bei `complain` den Schutz nicht belegt - der Prozess konnte die Aktion trotzdem ausführen.
</details>

<details>
<summary>2. Warum entfernt `allowPrivilegeEscalation: false` die bereits vergebene capability `SYS_ADMIN` nicht?</summary>

`allowPrivilegeEscalation: false` aktiviert das Kernel-Flag `no_new_privs`, das einem Prozess verbietet, NEUE Rechte über `execve` zu erlangen (zum Beispiel über eine setuid-Binärdatei oder file capabilities). Das betrifft nicht die Rechte, die der Prozess BEREITS in seinem effective/bounding set hat - wenn der Container mit der capability `SYS_ADMIN` explizit im Manifest gestartet wird, bleibt diese capability unabhängig vom Wert von `allowPrivilegeEscalation` verfügbar.
</details>

<details>
<summary>3. Warum wird `localhostProfile` im Pod-Manifest als relativer und nicht als absoluter Pfad angegeben?</summary>

Das Kubelet löst den relativen Pfad selbst relativ zu seinem seccomp root auf (standardmäßig `/var/lib/kubelet/seccomp/`). Wird ein absoluter Pfad angegeben, sucht das Kubelet die Datei in diesem seccomp root GENAU UNTER DIESEM ABSOLUTEN PFAD, was fast nie mit dem tatsächlichen Speicherort der Datei übereinstimmt - der Pod erhält `CreateContainerError`.
</details>

## Bezug zum Kurs

- [Kapitel 16. AppArmor](../../course/16/de.md)
- [Kapitel 17. seccomp](../../course/17/de.md)
- [Kapitel 03. Container Runtime Security](../../course/03/de.md)

## Infrastruktur

Die Umgebung wird über Terragrunt in AWS `eu-central-1` ausgerollt.

| Komponente | Zweck |
|---|---|
| `vpc` | VPC `10.10.0.0/16` mit öffentlichen Subnetzen |
| `ssh-keys` | Schlüssel für den Zugriff auf den Node |
| `k8s-1` | Ein-Node-kubeadm-Cluster Kubernetes `1.36.0`, containerd und **Calico** |
| `worker` | Arbeitsmaschine mit `kubectl`, `check_result` und SSH-Zugriff auf den Node als `control-plane` |

Zur Ressourcenschonung ist die control-plane der einzige workload-Node: Von ihr wurde der
`NoSchedule` taint entfernt. Sie ist mit dem Label
`security.cks.io/localhost-profiles-106=true` markiert. Alle Pods dieser Lab müssen gerade diesen
Node auswählen - das plan-Profil wird vom Scheduler (scheduler) nicht auf einen anderen Node übertragen.

Der Bootstrap hat **nur** vorbereitet:

- das Node-Label `security.cks.io/localhost-profiles-106=true` für sicheres Placement;
- auf der Arbeitsmaschine (worker), in `/opt/lab106-fixtures/`: die Quellen `k8s-106-deny-write`
  (AppArmor profile) und `cks-106-deny-unshare.json` (custom seccomp profile).

Weder das AppArmor profile noch das seccomp profile sind auf dem workload-Node **vorinstalliert** und
in dessen Kernel geladen - der Transfer und das erstmalige Laden jedes von ihnen sind Teil der Aufgaben 1 und 5.
Ändere nicht den Pfad des seccomp profile und erstelle kein profile innerhalb eines gewöhnlichen Pods: Der Transfer
der Dateien auf den Node erfolgt durch dich als Node-Administrator per SSH und nicht aus dem workload heraus.

## Bereitstellung

```bash
TASK=106 make run_cks_task
```

Verbinde dich per SSH mit der Arbeitsmaschine. Der Kontext ist bereits eingerichtet:

```bash
kubectl config use-context cluster1-admin@cluster1
time_left
check_result
```

Prüfe den Node-Zugriff und die worker-seitigen fixtures vor Beginn der Arbeit:

```bash
kubectl get nodes -L security.cks.io/localhost-profiles-106
ssh control-plane sudo aa-status
ls -la /opt/lab106-fixtures/
```

## Aufgaben

---
| **1** | **AppArmor profile übertragen und laden** |
| :---: | :--- |
| Was wir tun | Die Quelle des profile `k8s-106-deny-write` liegt nur auf der Arbeitsmaschine, in `/opt/lab106-fixtures/k8s-106-deny-write`. Kopiere sie auf den Node `control-plane` nach `/etc/apparmor.d/k8s-106-deny-write` (zum Beispiel per `scp`) und lade sie über `sudo apparmor_parser -r` in den Kernel. Das profile enthält bereits das Flag `complain` - es muss nicht ein zweites Mal aktiviert werden, das ist die Aufgabe von Aufgabe 2. |
| Abnahmekriterien | `/etc/apparmor.d/k8s-106-deny-write` ist auf dem Node vorhanden; `/sys/kernel/security/apparmor/profiles` enthält eine Zeile mit dem Namen `k8s-106-deny-write` (in jedem Modus - `complain` oder `enforce`), das heißt, das profile ist tatsächlich in den Kernel geladen und nicht einfach nur auf die Platte kopiert. |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

`scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/` kopiert die Datei auf den Node
in ein temporäres Verzeichnis; verschiebe sie von dort mit `sudo` nach `/etc/apparmor.d/` (ein gewöhnlicher
Benutzer hat dort kein direktes Schreibrecht). Dann kompiliert und lädt `sudo apparmor_parser -r
/etc/apparmor.d/k8s-106-deny-write` das profile in den Kernel - ohne diesen
Schritt bietet die Datei auf der Platte überhaupt keinen Schutz und erscheint nicht in
`/sys/kernel/security/apparmor/profiles`.
</details>

---
| **2** | **AppArmor profile in enforce überführen** |
| :---: | :--- |
| Was wir tun | Überführe auf dem Node `control-plane` das in Aufgabe 1 geladene profile `k8s-106-deny-write` in den Modus `enforce`. Der ursprüngliche Modus `complain` protokolliert Verletzungen, ist aber kein Schutz. Lösche das profile nicht und ändere seinen Namen nicht. |
| Abnahmekriterien | Der Node mit dem Label `security.cks.io/localhost-profiles-106=true` existiert; `/etc/apparmor.d/k8s-106-deny-write` ist verfügbar; `/sys/kernel/security/apparmor/profiles` enthält die Zeile `k8s-106-deny-write (enforce)`. Die checker-owned bootstrap-Baseline (VOR der Ausgabe der Lab festgehalten, an einer transitiven Kopie desselben profile, solange es noch in `complain` war) bestätigt, dass ein dem Muster `/work/**` dieses profile entsprechendes Schreiben damals tatsächlich durchging - ohne dies lässt sich nicht belegen, dass gerade der Übergang nach `enforce` die spätere Ablehnung verursacht hat. |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Der Befehl `sudo apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write` lädt ein bereits vorhandenes Profil neu - wenn es in `complain` war und die Datei auf der Platte bereits `enforce` beschreibt, genügt dieser Befehl. Prüfe dich selbst über `sudo cat /sys/kernel/security/apparmor/profiles | grep k8s-106-deny-write` - die Ausgabe muss ausdrücklich `(enforce)` zeigen. Prüfe das nicht über `aa-status`: Dieser Befehl gruppiert Profile unter Abschnittsüberschriften (`N profiles are in enforce mode.`) und gibt darunter nur die nackten Profilnamen aus, OHNE das Suffix `(enforce)`/`(complain)` in jeder Zeile - ein solches Suffix gibt es nur in `/proc/<pid>/attr/current` und in der Kerneldatei `/sys/kernel/security/apparmor/profiles`, aber nicht in der Profilliste von `aa-status`.

Verwende `aa-enforce`/`aa-complain` für dieses Profil nicht, bevor Aufgabe 9 erledigt ist:
Diese Python-Werkzeuge aus `apparmor-utils` parsen vor ihrer eigentlichen Arbeit
**alle** Dateien in `/etc/apparmor.d/`, einschließlich des noch defekten `k8s-106-broken-profile`
aus Aufgabe 8, und scheitern mit einem Parser-Fehler an einer fremden Datei. Bearbeite das Flag `complain` in der Datei
des Profils direkt (`sed`) und lade gerade DIESE Datei über `apparmor_parser -r` neu -
diese Binärdatei parst im Unterschied zu `aa-enforce` nur die ihr übergebene Datei.
</details>

---
| **3** | **Localhost AppArmor Pod und Schreibblockade** |
| :---: | :--- |
| Was wir tun | Erstelle den Namespace `security-106` und den Pod `apparmor-writer`. Der Pod muss das Node-Label aus der Infrastruktur auswählen, das automount des ServiceAccount token deaktivieren und auf Pod-Ebene `appArmorProfile.type: Localhost`, `localhostProfile: k8s-106-deny-write` setzen. Verwende `busybox:1.36`, den Container `app`, den Sleep-Befehl `sleep 3600` und ein `emptyDir`, das nach `/work` gemountet ist. Bestätige nach dem Start das effektive profile mit dem Befehl `cat /proc/1/attr/current` (falls die Schnittstelle verfügbar ist), führe eine erlaubte Leseoperation aus, zum Beispiel `cat /etc/hostname >/dev/null`, und versuche dann, eine Datei nach `/work` zu schreiben; die Operation muss mit einer Ablehnung enden. Halte auf dem Node den AppArmor denial für profile/process aus `journalctl -k \| grep -i apparmor` oder `dmesg \| grep -i apparmor` fest. |
| Abnahmekriterien | Der Pod läuft, verwendet gerade das Localhost profile und den richtigen nodeSelector; das effektive profile des Prozesses zeigt `k8s-106-deny-write` im enforce mode (wenn `/proc/.../attr/current` verfügbar ist); die erlaubte Leseoperation in `/work` geht durch, während der Checker unabhängig seine eigene eindeutige (per-run) Datei nach `/work` schreibt und eine AppArmor-Ablehnung erhält. Im kernel journal/audit log gibt es ein Ereignis `apparmor="DENIED"` mit diesem profile, das sich gerade auf DIESEN Versuch bezieht (anhand des eindeutigen Dateinamens) - das schließt einen false pass durch ein veraltetes denial-Ereignis im Journal aus. |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

`appArmorProfile` wird für ein Profil vom Typ `Localhost` über zwei getrennte Felder angegeben: `type: Localhost` und `localhostProfile: k8s-106-deny-write` (Name des Profils OHNE den Pfad `/etc/apparmor.d/`) - das ist derselbe Name, unter dem das Profil in Aufgabe 1 geladen wurde. Wenn der Pod nicht startet (CreateContainerError), prüfe, dass das Profil tatsächlich bereits auf dem RICHTIGEN Node geladen ist, den der nodeSelector auswählt - AppArmor-Profile sind node-local, sie werden nicht automatisch übertragen.
</details>

---
| **4** | **Sichere Baseline seccomp RuntimeDefault** |
| :---: | :--- |
| Was wir tun | Erstelle in `security-106` den Pod `runtime-default` mit `busybox:1.36` und `sleep 3600`. Gib auf Pod-Ebene explizit `securityContext.seccompProfile.type: RuntimeDefault` an; der Pod muss außerdem den vorbereiteten Node auswählen. Prüfe im Container `/proc/1/status`: erwartet wird `Seccomp: 2`. |
| Abnahmekriterien | Der Pod ist `Running`, in seinem Pod-level securityContext ist `RuntimeDefault` gewählt, und der Prozess befindet sich im seccomp filter mode. |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

`Seccomp: 2` in `/proc/1/status` bedeutet "filter mode aktiv" (SECCOMP_MODE_FILTER) - das ist es, was du sehen sollst. `Seccomp: 0` würde das Fehlen eines seccomp filter überhaupt bedeuten (`Unconfined`). Das ist die einfachste Aufgabe der fünf in dieser Gruppe - wenn sie nicht besteht, liegt das Problem sehr wahrscheinlich im nodeSelector und nicht im seccompProfile selbst.
</details>

---
| **5** | **Custom Localhost seccomp profile übertragen und verwenden** |
| :---: | :--- |
| Was wir tun | Die Quelle `cks-106-deny-unshare.json` liegt nur auf der Arbeitsmaschine, in `/opt/lab106-fixtures/cks-106-deny-unshare.json`. Bestimme den Node mit dem Label `security.cks.io/localhost-profiles-106=true`, erstelle darauf das Verzeichnis `/var/lib/kubelet/seccomp/profiles/` (falls es noch nicht existiert) und kopiere das JSON unter demselben Namen dorthin. Erstelle dann den Pod `localhost-seccomp` in `security-106` auf diesem Node. Gib auf Pod-Ebene `seccompProfile.type: Localhost` und den relativen Pfad `profiles/cks-106-deny-unshare.json` an - ohne `/var/lib/kubelet/seccomp/`. Der Container `app` muss `busybox:1.36` verwenden, die capability `SYS_ADMIN` erhalten und nach der Prüfung weiterlaufen. **Gib diese Kombination nicht als hardened Baseline aus:** `SYS_ADMIN` bleibt eine der gefährlichsten capabilities, und `allowPrivilegeEscalation: false` nimmt bereits vergebene Rechte nicht weg. Das ist ein capability-focused experiment, bei dem die Sicherheit durch ein konkretes seccomp deny gezeigt wird. |
| Abnahmekriterien | Das JSON profile ist übertragen und existiert auf dem Node am richtigen Pfad; der Pod mit dem richtigen nodeSelector verwendet das profile `Localhost:profiles/cks-106-deny-unshare.json`; das JSON profile enthält `SCMP_ACT_ERRNO`/`errnoRet: 1` für `unshare`; im Container wird nur das für das Experiment erforderliche `SYS_ADMIN` hinzugefügt. |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

Der Pfad `profiles/cks-106-deny-unshare.json` ist relativ zum kubelet seccomp root `/var/lib/kubelet/seccomp/`, das heißt, die tatsächliche Datei auf dem Node muss unter der Adresse `/var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json` liegen - gerade dorthin muss sie von der Arbeitsmaschine kopiert werden (zum Beispiel `scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/`, dann `sudo mkdir -p` und `sudo mv` auf dem Node). Schreibe im Manifest nicht den vollständigen absoluten Pfad - das kubelet fügt den root selbst hinzu. `SYS_ADMIN` wird hier GERADE für das Experiment vergeben (es wird eine capability gebraucht, die es grundsätzlich erlaubt, `unshare` aufzurufen) und nicht als empfohlene Praxis - verwechsle das Lernszenario nicht mit der production-Baseline.
</details>

---
| **6** | **Ablehnung des syscall `unshare(2)` belegen** |
| :---: | :--- |
| Was wir tun | Führe im Befehl des Containers `localhost-seccomp` `unshare -n true` aus, speichere die erfolgreiche Bestätigung der erwarteten Ablehnung in `/tmp/unshare-result` als Zeile `unshare denied by seccomp` und halte dann den Container über `sleep 3600` am Laufen. Ein erneutes `kubectl exec ... -- unshare -n true` muss einen Exit-Code ungleich null liefern. Erstelle als attack-minded negative control den Pod `sysadmin-control` auf demselben Node mit `seccompProfile.type: Unconfined` und derselben einzigen capability `SYS_ADMIN`; sein `unshare -n true` muss erfolgreich enden. Lösche den control Pod nach der Prüfung. |
| Abnahmekriterien | Der Localhost Pod läuft; `Seccomp: 2`; `unshare` wird vom custom profile blockiert. Im control Pod geht derselbe syscall mit derselben capability und ohne seccomp filter durch. Das belegt das Kernel-Verhalten und nicht nur das Vorhandensein von YAML. |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

Verwende gerade `unshare -n true` (unshare network namespace, `CLONE_NEWNET`) und NICHT
`unshare -m true`. `-m` (mount namespace) erfordert ebenso wie `-n` `CAP_SYS_ADMIN`, aber
BusyBox `unshare -m` führt nach erfolgreichem `unshare(2)` zusätzlich einen ZWEITEN,
eigenständigen `mount(2)` syscall aus (`mount("none", "/", NULL, MS_REC|MS_PRIVATE, NULL)`
zur Erzwingung der private propagation - das ist ein standardmäßig aktives Verhalten von unshare,
wenn nicht explizit `--propagation unchanged` übergeben wird, und selbst dann wird `mount()` trotzdem
aufgerufen, nur mit Null-Flags). Das default AppArmor-Profil von containerd (`RuntimeDefault`,
das ein Pod ohne explizites `securityContext.appArmorProfile` erhält) enthält `deny mount,`
OHNE irgendwelche Bedingungen an Flags - dieses Verbot gilt unabhängig von capabilities und von
seccomp. Deshalb kann `unshare -m true` wegen AppArmor mit `EPERM` scheitern, SELBST wenn
seccomp `unshare` überhaupt nicht einschränkt, was einen solchen Probe zu einem unzuverlässigen Beleg
gerade für eine seccomp-Ablehnung macht. `unshare -n` (`CLONE_NEWNET`) ruft NUR den
syscall `unshare(2)` selbst ohne nachfolgendes `mount()` auf - und `localhost-seccomp` sowie
`sysadmin-control` verwenden dasselbe `SYS_ADMIN`, daher erklärt sich der Unterschied im Ergebnis
eindeutig gerade durch den seccomp filter und nicht durch einen Nebeneffekt von AppArmor.

Die Reihenfolge der Befehle ist für die Beweiskraft wichtig: Führe zuerst `unshare -n true` aus und vergewissere dich, dass es mit einem Fehler scheitert (Exit-Code ungleich null), ERST DANN schreibe die Zeile `unshare denied by seccomp` nach `/tmp/unshare-result` - schreibe die Zeile nicht vorab, indem du das Ergebnis "annimmst". Der negative control (`sysadmin-control`) muss DIESELBE capability `SYS_ADMIN` verwenden, aber `seccompProfile.type: Unconfined` - wenn du vergisst, `Unconfined` explizit anzugeben, kann der Pod standardmäßig `RuntimeDefault` erhalten (wenn `seccompDefault` aus Aufgabe 8 aktiviert ist), und der Test zeigt den Unterschied nicht.
</details>

Linux capabilities und privilege escalation sind unterschiedliche Achsen. `allowPrivilegeEscalation: false`
aktiviert `no_new_privs` und verbietet, **neue** Rechte über `execve` zu erlangen (setuid/setgid und
file capabilities), entfernt aber das bereits in das bounding/effective set aufgenommene `SYS_ADMIN` nicht.
Verwende für einen gewöhnlichen workload `capabilities.drop: ["ALL"]` und separat
`allowPrivilegeEscalation: false`; das obige Experiment ist absichtlich keine solche Baseline.

---
| **7** | **User namespaces: `hostUsers: false` und UID-Übersetzung über `uid_map`** |
| :---: | :--- |
| Was wir tun | User namespaces sind in Kubernetes v1.36 GA (siehe [Kapitel 03](../../course/03/de.md), [Kapitel 18](../../course/18/de.md) und Security Delta v1.36). Die Theorie erklärt, dass `hostUsers: false` das root des Containers in eine unprivilegierte host UID übersetzt; hier musst du das an einem laufenden Prozess belegen. Erstelle in `security-106` auf dem vorbereiteten Node einen Pod `userns-probe` mit `spec.hostUsers: false`, dem Image `busybox:1.36`, dem Befehl `sleep 3600`; setze kein Pod-level `runAsUser`, damit der Prozess als UID 0 **innerhalb** des Containers startet. Bestätige `id` im Container (`uid=0`). Bestimme die host PID des Container-Prozesses über `crictl inspect` (analog zu Lab 112) oder über `kubectl get pod -o jsonpath` + `crictl ps`, lies dann auf dem Node `/proc/<host PID>/uid_map`. Speichere beide Ausgaben (`id` im Container und den Inhalt von `uid_map`) in `/var/work/tests/artifacts/6/userns.txt`. |
| Abnahmekriterien | Der Pod ist `Running`, `spec.hostUsers == false`, wählt den vorbereiteten Node aus; `id` im Container zeigt `uid=0(root)`; `/proc/<host PID>/uid_map` auf dem Node enthält eine Zeile der Form `0 <host-uid> <length>`, wobei `<host-uid>` **nicht gleich 0** ist (das root des Containers wurde in eine unprivilegierte host UID übersetzt) und `<length>` mindestens `65536` beträgt (der standardmäßige per-Pod UID-Bereich); das artifact enthält beide Teile der evidence. |

<details>
<summary>💡 Hinweis zu Aufgabe 7</summary>

`id` INNERHALB des Containers zeigt unabhängig von `hostUsers` `uid=0(root)` - das ist erwartet, der Container sieht SEINEN eigenen Namespace, in dem sein root tatsächlich UID 0 in diesem Namespace ist. Der echte Schutz ist nur von AUSSEN sichtbar: auf dem Node selbst, in `/proc/<host PID>/uid_map`, wo die UID 0 im Container in eine große unprivilegierte UID auf dem Host übersetzt wird. Um die host PID zu finden, verwende `crictl inspect <container-id>` - gerade von dort und nicht von `kubectl get pod`, der nur das Kubernetes-Objekt kennt, aber nicht die host-level PID des Prozesses.
</details>

---
| **8** | **`seccompDefault: true` auf Ebene des kubelet: Baseline ohne explizites Profil** |
| :---: | :--- |
| Was wir tun | Alle Pods in den Aufgaben 4–6 geben `seccompProfile` explizit im Manifest an. In der Realität kann ein Entwickler dieses Feld vergessen - dann erhält der Pod ohne node-level Baseline `Unconfined`. Aktiviere auf dem Node `seccompDefault: true` in `/var/lib/kubelet/config.yaml` und starte kubelet neu (`systemctl restart kubelet`). Erstelle den Pod `no-seccomp-field` in `security-106` auf dem vorbereiteten Node aus `busybox:1.36` (`sleep 3600`), **ohne securityContext.seccompProfile überhaupt anzugeben**, weder auf Pod- noch auf Container-Ebene. Bestätige über `/proc/1/status` im Container, dass das kubelet `RuntimeDefault` automatisch angewendet hat (`Seccomp: 2`) und nicht `Unconfined` (`Seccomp: 0`) belassen hat. |
| Abnahmekriterien | Die effektive (angewendete) Konfiguration des kubelet - über `/api/v1/nodes/<node>/proxy/configz`, das Feld `.kubeletconfig.seccompDefault` - ist gleich `true`; `systemctl is-active kubelet` gibt `active` zurück, der Node bleibt `Ready`; der Pod `no-seccomp-field` hat auf keiner Ebene seiner Spezifikation ein `seccompProfile`; `/proc/1/status` im Container zeigt `Seccomp: 2`. |

<details>
<summary>💡 Hinweis zu Aufgabe 8</summary>

Die Kernanforderung ist, dass der Pod `seccompProfile` WIRKLICH überhaupt nicht erwähnen darf, weder auf Pod- noch auf Container-Ebene. Wenn du das Manifest aus Aufgabe 3 kopierst und einfach vergisst, dieses Feld zu entfernen, beweist der Test nicht, was er beweisen soll: dass gerade das node-level `seccompDefault` (und nicht die explizite Angabe im Manifest) `Seccomp: 2` bewirkt hat.

Die Prüfung orientiert sich an der TATSÄCHLICH ANGEWENDETEN Konfiguration des kubelet und nicht am Text der Datei auf
der Platte: `curl`/`kubectl get --raw /api/v1/nodes/<node>/proxy/configz | jq .kubeletconfig.seccompDefault`.
Ein einfaches grep auf `/var/lib/kubelet/config.yaml` beweist nicht, dass das laufende kubelet gerade diese Datei
verwendet - ein Kommandozeilen-Flag oder ein drop-in könnte den Wert überschreiben, ohne die Datei selbst zu ändern.
Starte das kubelet nach dem Bearbeiten der Datei unbedingt neu - die Konfiguration wird nicht im laufenden Betrieb übernommen.
</details>

---
| **9** | **Debuggen und Neuaufbau eines defekten AppArmor-Profils (`apparmor_parser -r -v`)** |
| :---: | :--- |
| Was wir tun | Auf der Platte liegt bereits `/etc/apparmor.d/k8s-106-broken-profile` - ein Profil mit einem Syntaxfehler, das **nie in den Kernel geladen** wurde. Finde den Fehler selbstständig über `sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile` (`-Q`/`--skip-kernel-load`: führt die Prüfung/Kompilierung des Profils vollständig aus, lädt es aber nicht in den Kernel) oder `sudo apparmor_parser -d /etc/apparmor.d/k8s-106-broken-profile` (`-d`/`--debug`, einmalig - nur Prüfung der syntaktischen Korrektheit), korrigiere die Datei und lade das Profil über `sudo apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile` in den Kernel. Bestätige das Laden über `aa-status \| grep k8s-106-broken-profile`. Speichere die Fehlerausgabe **vor** der Korrektur und die Bestätigung des Ladens **danach** in `/var/work/tests/artifacts/8/apparmor-debug.txt`. |
| Abnahmekriterien | `apparmor-debug.txt` enthält den Text des Parser-Fehlers (zum Beispiel `syntax error`) aus dem Versuch **vor** der Korrektur; die checker-owned bootstrap-Baseline (VOR der Ausgabe der Lab festgehalten, unabhängig von deinem artifact) bestätigt unabhängig, dass das ursprüngliche Profil tatsächlich einen syntax error enthielt; `/etc/apparmor.d/k8s-106-broken-profile` auf der Platte enthält den ursprünglichen Syntaxfehler nicht mehr; `aa-status` zeigt `k8s-106-broken-profile` unter den geladenen Profilen (in jedem Modus - `enforce` oder `complain`); ein erneutes `apparmor_parser -Q` auf die korrigierte Datei endet ohne Fehler. |

<details>
<summary>💡 Hinweis zu Aufgabe 9</summary>

`apparmor_parser -p` (`--preprocess`) ist KEIN sicherer dry-run/Syntaxprüfungs-Modus - das ist
lediglich preprocessing: Es expandiert `#include`-Direktiven und gibt das entstandene
Profil auf stdout aus, garantiert an sich keine Abwesenheit von Nebenwirkungen und ist nicht
gerade zur Prüfung der Syntax gedacht. Verwende `-Q`/`--skip-kernel-load`
(führt die vollständige Kompilierung/Prüfung aus, lädt aber nicht in den Kernel) oder `-d`/`--debug`
(einmalig - nur Prüfung der syntaktischen Korrektheit), um den Syntaxfehler SICHER und ohne Nebenwirkungen
zu finden. Erst nach der Korrektur der Datei verwende
`-r` (reload/load) für das tatsächliche Laden in den Kernel. Die AppArmor-Syntax verlangt ein Komma
als Trennzeichen der Regeln innerhalb eines Blocks - studiere die Ausgabe des Parsers, um zu finden, welches Zeichen
fehlt und wo genau.

Starte `apparmor_parser` über `sudo`, auch mit `-Q`/`-d`: Auf dem Lab-Node (apparmor 3.0.4,
Ubuntu) versucht der Parser ohne Privilegien bei jedem Start, den policy cache in
`/var/cache/apparmor` einzurichten, und scheitert mit "Failed setting up policy cache: Permission denied" VOR
der Syntaxprüfung - du erhältst einen irreführenden Fehler zu Rechten statt des echten Syntaxfehlers
des Profils. Das wurde auf dem Node selbst verifiziert (auch an einem nachweislich defekten Profil).
Wenn du ohne `sudo` starten musst, füge `-K` hinzu (`--skip-cache`: kein Caching) -
`apparmor_parser -Q -K` ohne Privilegien gelangt bis zum Parsen des Profils und zeigt den echten
Fehler. Laden und reload (`-r`) erfordern in jedem Fall Privilegien.
</details>

## Prüfung

Führe auf der Arbeitsmaschine aus:

```bash
check_result
```

Die Prüfung enthält Init und neun unabhängige Tests. Sie liest den Pod-state über die API, prüft das
profile auf dem Node per SSH und führt kontrollierte negative Szenarien aus. Wenn ein Localhost
Pod nicht erstellt wird, sieh dir zuerst `kubectl describe pod` an: Die übliche Ursache ist ein absoluter
Pfad statt eines relativen oder die Zuweisung des Pods an einen Node ohne profile.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=106 make delete_cks_task
```
