[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 - Referenzlösung: AppArmor und seccomp

> Kubernetes-Befehle (`kubectl`) führst du auf der Arbeitsmaschine (`worker`) aus. Alles, was den
> Node selbst betrifft (AppArmor, kubelet, `crictl`), machst du **direkt auf dem Node**: Melde dich einmal per `ssh` an
> und werde root (`sudo -i`) - das ist schneller, als jeden Befehl mit einem separaten
> `ssh control-plane '...'` zu senden, und genau so sollte man in der CKS-Prüfung arbeiten. Der Namespace
> `security-106` wird in Aufgabe 3 erstellt.
>
> ```bash
> ssh control-plane
> sudo -i
> # ... Befehle auf dem Node ...
> exit   # aus root
> exit   # vom Node zurück zum worker
> ```
>
> Die Prüfung liest die artifacts von der **Arbeitsmaschine** (`/var/work/tests/artifacts/<Nummer>/`), sie
> werden nur für die Lab gebraucht - in der CKS-Prüfung gibt es sie nicht. Wir speichern sie mit einem kurzen Befehl vom `worker`
> (`> Datei`), den Inhalt sehen wir separat über `cat <Datei>`.

## 1. Übertragung und Laden des AppArmor profile

Das Profil liegt nur auf der Arbeitsmaschine. Wir kopieren es auf den Node (vom `worker`), dann legen wir es dort
an die richtige Stelle und laden es in den Kernel. Die Datei enthält bereits das Flag `complain`, daher genügt ein einziges
`apparmor_parser -r` für das erstmalige Laden (ohne `aa-complain`, das wie
`aa-enforce` alle Dateien in `/etc/apparmor.d/` parst und am noch defekten
`k8s-106-broken-profile` aus Aufgabe 9 scheitern würde):

```bash
# auf dem worker
scp /opt/lab106-fixtures/k8s-106-deny-write control-plane:/tmp/k8s-106-deny-write

# auf dem Node
ssh control-plane
sudo -i
mv /tmp/k8s-106-deny-write /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# erwartet: "k8s-106-deny-write":	"complain",
```

## 2. AppArmor profile in enforce überführen

Das Profil ist derzeit im Modus `complain` (in Aufgabe 1 mit diesem Flag geladen). Wir bleiben auf dem Node
(als root) und überführen genau das vorhandene Profil in den enforcing mode:

```bash
sed -i 's/, complain,/,/' /etc/apparmor.d/k8s-106-deny-write
apparmor_parser -r /etc/apparmor.d/k8s-106-deny-write
aa-status --pretty-json | grep k8s-106-deny-write
# erwartet: "k8s-106-deny-write":	"enforce",
# Ein gewöhnliches 'aa-status | grep ...' zeigt den Modus des Profils nicht: In der Textausgabe sind die Profile
# unter Überschriften gruppiert ('N profiles are in enforce mode.'), die Namen stehen ohne Suffix.
# Zur Prüfung eines konkreten Profils verwende 'aa-status --pretty-json' (oder '--json').
exit
exit
```

Verwende `aa-enforce`/`aa-complain` und andere in Python geschriebene Werkzeuge zum Ändern von Profilen aus dem
Paket `apparmor-utils` für DIESES Profil nicht, bevor Aufgabe 9 erledigt ist: Sie rufen intern `apparmor.read_profiles()` auf, das beim Start
**alle** Dateien in `/etc/apparmor.d/` parst, einschließlich des noch nicht geladenen und nachweislich
defekten `/etc/apparmor.d/k8s-106-broken-profile` aus Aufgabe 9 - und sie scheitern mit einem Fehler des
Parsers an einer FREMDEN Datei, ohne überhaupt bis zu deinem Profil zu kommen. `apparmor_parser`
(eine Binärdatei, kein Python-Wrapper), direkt mit EINER konkreten Datei aufgerufen, parst
nur diese und ist von diesem Problem nicht betroffen - genau deshalb bearbeiten wir das Flag des Profils
(entfernen `complain` aus `flags=(...)`) von Hand über `sed` und laden dann gerade
diese Datei über `apparmor_parser -r` neu.

`aa-status` ist ein separates Werkzeug zur Anzeige des Zustands und kein Werkzeug zum Ändern von Profilen, und hierher
gehört es nicht. Den Modus eines konkreten Profils zeigt `aa-status --pretty-json` (auf dem
Lab-Node verifiziert, apparmor 3.0.4; `--json` liefert dasselbe in einer Zeile, zum Beispiel
`aa-status --json | jq -r '.profiles["k8s-106-deny-write"]'`). Alternativ ist die Kerneldatei
`grep -F 'k8s-106-deny-write' /sys/kernel/security/apparmor/profiles`: Dort ist das Format
`name (enforce|complain)`.

## 3. Pod mit Localhost AppArmor und Schreibverweigerung

Wir erstellen Namespace und Pod. `emptyDir` garantiert das Vorhandensein von `/work`; das profile erlaubt den
Start des Prozesses, verbietet aber das Schreiben in diesem Verzeichnis. Der Node selector bindet den Pod an
den Node, auf dem das profile tatsächlich geladen ist.

```yaml
# apparmor-writer.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: security-106
---
apiVersion: v1
kind: Pod
metadata:
  name: apparmor-writer
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    appArmorProfile:
      type: Localhost
      localhostProfile: k8s-106-deny-write
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: work
      mountPath: /work
  volumes:
  - name: work
    emptyDir: {}
```

```bash
# auf dem worker
kubectl apply -f apparmor-writer.yaml
kubectl get pod -n security-106 apparmor-writer
# warte auf STATUS Running (wiederhole get), führe dann exec aus

# Evidence: Das Profil ist tatsächlich dem Prozess PID 1 zugewiesen und nicht nur ins Pod YAML geschrieben.
kubectl exec -n security-106 apparmor-writer -- cat /proc/1/attr/current
# k8s-106-deny-write (enforce)

# Positive control VOR der Ablehnung: eine erlaubte read-Operation gerade auf demselben /work,
# an dem der denial geprüft wird - ohne diesen Schritt ließe sich die Schreibablehnung nicht
# von einem völlig nicht funktionierenden mount/mountPath unterscheiden (in diesem Fall wäre sogar das Lesen nicht verfügbar).
kubectl exec -n security-106 apparmor-writer -- sh -c 'ls /work'

# Negative control: Der denial muss genau eine AppArmor-Ablehnung des Schreibens sein.
kubectl exec -n security-106 apparmor-writer -- \
  sh -c 'printf blocked >/work/cks-106-denied.txt'
# erwartet wird ein Code ungleich null: Permission denied / Operation not permitted
```

Ein Exit-Code ungleich null und der Text 'permission denied' beweisen für sich genommen NICHT, dass gerade
diese AppArmor-Regel gegriffen hat - ein gewöhnlicher DAC/Dateisystem-Fehler sähe aus Sicht der shell
identisch aus. Verknüpfe die Ablehnung gerade mit diesem profile über das kernel audit log; wir sehen es
auf dem Node unmittelbar nach dem obigen Versuch an:

```bash
# auf dem Node
ssh control-plane
sudo -i
journalctl -k --no-pager -n 500 | grep -F 'apparmor="DENIED"' | grep -F 'profile="k8s-106-deny-write"' | grep -F 'cks-106-denied.txt'
# erwartet wird ein Eintrag der Form: ... apparmor="DENIED" ... profile="k8s-106-deny-write" name=".../cks-106-denied.txt" ... denied_mask="c" ... (mknod: Erstellen einer Datei; beim Schreiben in eine vorhandene Datei steht dort "w")
exit
exit
```

Wenn `/proc/1/attr/current` in der konkreten runtime nicht verfügbar ist, halte das fest und stütze dich auf
die Zuweisung des Localhost profile zusammen mit dem kernel `apparmor="DENIED"` für dieses profile;
ein einzelner Code ungleich null ohne diese evidence reicht nicht, denn er kann auch durch ein mount-Problem oder gewöhnliche
Unix-Rechte verursacht werden.

## 4. RuntimeDefault für einen gewöhnlichen Pod

`RuntimeDefault` ist die portable Baseline, die das Standardprofil von
containerd/runtime wählt. Das Feld ist explizit auf Pod-Ebene gesetzt.

```yaml
# runtime-default.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runtime-default
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
# auf dem worker
kubectl apply -f runtime-default.yaml
kubectl get pod -n security-106 runtime-default
kubectl exec -n security-106 runtime-default -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2
```

## 5–6. Localhost seccomp und Nachweis der Blockade von `unshare`

Die Datei liegt nur auf der Arbeitsmaschine, in `/opt/lab106-fixtures/cks-106-deny-unshare.json`.
Wir kopieren sie auf den Node (vom `worker`) und legen sie in den kubelet seccomp root (auf dem Node):

```bash
# auf dem worker
scp /opt/lab106-fixtures/cks-106-deny-unshare.json control-plane:/tmp/cks-106-deny-unshare.json

# auf dem Node
ssh control-plane
sudo -i
mkdir -p /var/lib/kubelet/seccomp/profiles
mv /tmp/cks-106-deny-unshare.json /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json
jq empty /var/lib/kubelet/seccomp/profiles/cks-106-deny-unshare.json && echo valid
exit
exit
```

In der API geben wir den Pfad relativ zum seccomp root an: `profiles/cks-106-deny-unshare.json`.

`SYS_ADMIN` ist hier eine absichtliche gefährliche Ausnahme nur für die Lab (die Prüfung des control ohne seccomp übernimmt der Checker). Ohne den custom
filter kann `unshare -n` mit dieser capability funktionieren; seccomp muss `EPERM` zurückgeben.
Das ist keine hardened Kombination. `allowPrivilegeEscalation: false` aktiviert `no_new_privs`, nimmt aber
die dem Prozess bereits vergebenen capabilities nicht weg, daher verwenden wir dieses Feld nicht als
„Kompensation“ für `SYS_ADMIN`. In production wird eine solche capability entfernt, wenn es keine nachgewiesene
Notwendigkeit gibt. In Kubernetes wird die capability als `SYS_ADMIN` geschrieben, ohne das Präfix `CAP_`.

Wir verwenden `unshare -n` (network namespace, `CLONE_NEWNET`) und NICHT `unshare -m` (mount
namespace). Beide Operationen erfordern dieselbe `CAP_SYS_ADMIN`, aber BusyBox `unshare -m`
führt nach erfolgreichem `unshare(2)` zusätzlich einen eigenständigen `mount(2)` syscall
für forced private propagation aus - und das default AppArmor-Profil von containerd (`RuntimeDefault`,
das dieser Pod erhält, da hier kein explizites `appArmorProfile` gesetzt ist) enthält
`deny mount,` ohne irgendwelche Bedingungen an Flags, unabhängig von capabilities/seccomp. Daher kann
`unshare -m true` wegen AppArmor mit `EPERM` scheitern, selbst wenn seccomp `unshare` überhaupt nicht
einschränkt - ein solcher Test würde zwei verschiedene security controls vermischen. `unshare -n`
ruft nur den syscall `unshare(2)` selbst auf, ohne begleitendes `mount()`.

```yaml
# localhost-seccomp.yaml
apiVersion: v1
kind: Pod
metadata:
  name: localhost-seccomp
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: Localhost
      localhostProfile: profiles/cks-106-deny-unshare.json
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      if unshare -n true 2>/tmp/unshare.err; then
        echo 'unshare unexpectedly succeeded' >/tmp/unshare-result
        exit 1
      fi
      grep -Eqi 'operation not permitted|permission denied' /tmp/unshare.err
      echo 'unshare denied by seccomp' >/tmp/unshare-result
      exec sleep 3600
    securityContext:
      capabilities:
        add: ["SYS_ADMIN"]
```

```bash
# auf dem worker
kubectl apply -f localhost-seccomp.yaml
kubectl get pod -n security-106 localhost-seccomp
kubectl exec -n security-106 localhost-seccomp -- cat /tmp/unshare-result
# unshare denied by seccomp

kubectl exec -n security-106 localhost-seccomp -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2

kubectl exec -n security-106 localhost-seccomp -- unshare -n true
# erwartet wird ein Code ungleich null: Operation not permitted / Permission denied
```

## 7. User namespaces: `hostUsers: false` und `uid_map`

`hostUsers: false` bittet das kubelet, dem Pod einen eigenen user namespace zuzuweisen: root (UID 0)
im Container wird auf einen unprivilegierten UID-Bereich des Hosts abgebildet. Wir setzen
`runAsUser` nicht, damit der Prozess tatsächlich als UID 0 **innerhalb** des Namespace startet - gerade dieser
Fall zeigt die Übersetzung und nicht das Fehlen von Privilegien von Anfang an.

```yaml
# userns-probe.yaml
apiVersion: v1
kind: Pod
metadata:
  name: userns-probe
  namespace: security-106
spec:
  hostUsers: false
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# auf dem worker
kubectl apply -f userns-probe.yaml
kubectl get pod -n security-106 userns-probe
mkdir -p /var/work/tests/artifacts/6

kubectl exec -n security-106 userns-probe -- id > /var/work/tests/artifacts/6/userns.txt
cat /var/work/tests/artifacts/6/userns.txt
# uid=0(root) gid=0(root) groups=0(root)
```

Die host PID des Containers stimmt weder mit der PID im Container überein, noch ist sie direkt über
`kubectl` sichtbar. Wir holen die Container-ID auf dem worker und die PID über `crictl inspect` auf dem Node,
auf dem der Pod tatsächlich läuft:

```bash
# auf dem worker
kubectl get pod userns-probe -n security-106 -o jsonpath='{.status.containerStatuses[0].containerID}'
# containerd://<ID> - kopiere <ID> ohne das Präfix containerd://

# auf dem Node
ssh control-plane
sudo -i
crictl inspect <ID> | jq -r '.info.pid'
# zum Beispiel: 15205 - das ist die <host PID>
```

`/proc/<host PID>/uid_map` auf dem Node beschreibt die Übersetzung: drei Zahlen - `<container-uid-start>
<host-uid-start> <length>`. Für `hostUsers: false` muss die erste Zeile mit `0` beginnen
(container UID 0), aber host-uid-start muss **ungleich null** sein - das ist gerade der
unprivilegierte Bereich des Hosts, und `length` ist der standardmäßige per-Pod Block von `65536` UIDs.

```bash
# auf dem Node (als root)
cat /proc/<host PID>/uid_map
# 0 1349844992 65536   (host-uid-start ist bei jedem Pod anders, Hauptsache nicht 0)
exit
exit
```

Wir speichern die Zeile `uid_map` im artifact (auf `worker`):

```bash
ssh control-plane "sudo cat /proc/<host PID>/uid_map" >> /var/work/tests/artifacts/6/userns.txt
```

Wenn `host-uid-start` gleich `0` ist, wurde der user namespace nicht angewendet (zum Beispiel wegen
eines inkompatiblen containerd/runc oder wegen eines fehlenden `hostUsers: false` im tatsächlich angewendeten
Pod) - das ist kein hardening, sondern ein gewöhnlicher Root-Benutzer auf dem Host. Zum Vergleich: Bei einem gewöhnlichen Pod ohne
`hostUsers: false` existiert die Datei `/proc/<host-PID>/uid_map` ebenfalls, aber der Prozess bleibt im
host (initial) user namespace. Daher beginnt das mapping mit UID 0 -> host UID 0 (normalerweise
eine Zeile der Form `0 0 4294967295`, zum Beispiel `cat /proc/1/uid_map` auf dem Node) und nicht mit
einer unprivilegierten per-Pod host UID. Bei `userns-probe` mit `hostUsers: false` erwarten wir das
Gegenteil: `0 <von-null-verschiedene-host-uid> <per-pod-bereich>`.

## 8. `seccompDefault: true` am kubelet

Alle vorherigen Pods haben `seccompProfile` explizit gesetzt. Hier prüfen wir die node-level Baseline:
Wenn der Entwickler dieses Feld vergisst, muss das kubelet selbst `RuntimeDefault` anwenden und nicht
den Prozess `Unconfined` lassen. Wir korrigieren die Konfiguration des kubelet auf dem Node:

```bash
# auf dem Node
ssh control-plane
sudo -i
grep -q '^seccompDefault:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^seccompDefault:.*/seccompDefault: true/' /var/lib/kubelet/config.yaml \
  || echo 'seccompDefault: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

```bash
# auf dem worker: Der Name des Nodes in der API ist nicht der Alias 'control-plane' aus /etc/hosts, sondern der echte Name des Nodes (ip-10-...)
kubectl get nodes     # Ready
```

Wir erstellen einen Pod ohne jede Erwähnung von `seccompProfile` - weder auf Pod- noch auf container level:

```yaml
# no-seccomp-field.yaml
apiVersion: v1
kind: Pod
metadata:
  name: no-seccomp-field
  namespace: security-106
spec:
  nodeSelector:
    security.cks.io/localhost-profiles-106: "true"
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
```

```bash
# auf dem worker
kubectl apply -f no-seccomp-field.yaml
kubectl get pod -n security-106 no-seccomp-field
kubectl exec -n security-106 no-seccomp-field -- grep '^Seccomp:' /proc/1/status
# Seccomp: 2  -- das kubelet hat RuntimeDefault selbst angewendet, ohne das Feld im Manifest

# Prüfe dich selbst über die TATSÄCHLICH ANGEWENDETE Konfiguration des kubelet, nicht über den Text der Datei auf der
# Platte - ein drop-in oder ein Kommandozeilen-Flag könnte den Wert überschreiben, ohne
# die config.yaml selbst zu ändern:
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl get --raw "/api/v1/nodes/${NODE}/proxy/configz" | jq '.kubeletconfig.seccompDefault'
# true
```

Ohne `seccompDefault: true` hätte dasselbe Manifest `Seccomp: 0` (`Unconfined`) ergeben - das lässt sich leicht
prüfen, indem man das Flag zurücksetzt und den Pod neu erstellt, falls man den Unterschied sehen möchte.

## 9. Debuggen eines defekten AppArmor-Profils

`/etc/apparmor.d/k8s-106-broken-profile` liegt bereits auf der Platte, wurde aber nie geladen: Darin fehlt
das Komma nach der Regel `deny /work/** w`. Zuerst finden wir den Fehler ohne Laden in den
Kernel. `-p`/`--preprocess` ist hier NICHT geeignet - das ist preprocessing (expandiert
`#include` nach stdout) und kein sicherer dry-run/syntax-check. Wir verwenden `-Q`/`--skip-kernel-load`
(vollständige Kompilierung/Prüfung ohne Laden in den Kernel) oder `-d`/`--debug`
(einmalig - nur syntax check).

Das artifact `apparmor-debug.txt` muss den **ursprünglichen** Parser-Fehler enthalten, daher
speichern wir es vor der Korrektur (auf dem `worker`):

```bash
mkdir -p /var/work/tests/artifacts/8
ssh control-plane 'sudo apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile' \
  > /var/work/tests/artifacts/8/apparmor-debug.txt 2>&1
cat /var/work/tests/artifacts/8/apparmor-debug.txt
# ... syntax error, unexpected TOK_CLOSE, expecting TOK_END_OF_RULE
```

Wir verwenden `sudo` auch für die compile-only Prüfung `-Q`: Auf dem Lab-Node (apparmor 3.0.4, Ubuntu)
versucht der Parser ohne Privilegien bei jedem Start, den policy cache in
`/var/cache/apparmor` einzurichten, und scheitert mit "Failed setting up policy cache (/var/cache/apparmor):
Permission denied" VOR der Syntaxprüfung - du erhältst eine irreführende Berechtigungsfehlermeldung statt des
echten Syntaxfehlers, und `apparmor-debug.txt` enthält nicht den benötigten Text
"syntax error". Auf dem Node selbst verifiziert, auch an einem nachweislich defekten Profil.
Die Alternative ohne `sudo` ist, `-K`/`--skip-cache` hinzuzufügen (`apparmor_parser -Q -K ...`): Ohne
Caching gelangt der Parser bis zum Parsen des Profils. `sudo` ist in dieser Lab für einen einheitlichen
Workflow mit dem späteren `-r` gewählt, das in jedem Fall Privilegien erfordert.

Wir korrigieren auf dem Node: Eine AppArmor-Regel muss mit einem Komma enden. Dann laden wir das
korrigierte Profil in den Kernel - gerade mit `-r -v` (reload + verbose) und nicht mit `-Q`/`-p`, die
nichts laden:

```bash
# auf dem Node
ssh control-plane
sudo -i
sed -i 's/^\(\s*deny \/work\/\*\* w\)$/\1,/' /etc/apparmor.d/k8s-106-broken-profile
tail -5 /etc/apparmor.d/k8s-106-broken-profile
apparmor_parser -r -v /etc/apparmor.d/k8s-106-broken-profile
aa-status --pretty-json | grep k8s-106-broken-profile
# erwartet: "k8s-106-broken-profile":	"enforce",
```

Abschließende Prüfung, dass die Datei jetzt ohne Fehler gültig ist:

```bash
apparmor_parser -Q /etc/apparmor.d/k8s-106-broken-profile
echo "exit: $?"
# exit: 0
exit
exit
```

Ergänze jetzt auf dem `worker` die Bestätigung des Ladens NACH der Korrektur im selben artifact:

```bash
ssh control-plane 'sudo aa-status --pretty-json' | grep k8s-106-broken-profile >> /var/work/tests/artifacts/8/apparmor-debug.txt
cat /var/work/tests/artifacts/8/apparmor-debug.txt
```

Starte zum Schluss (auf `worker`):

```bash
check_result
```
