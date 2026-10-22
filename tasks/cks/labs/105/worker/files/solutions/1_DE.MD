[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 105 - Referenzlösung: System Hardening des Betriebssystems und Docker

> So wird gearbeitet: Wir melden uns einmal per `ssh` auf dem Node an und führen die Befehle direkt dort aus (unter
> `sudo -i`, um nicht vor jeden Befehl `sudo` zu schreiben) - das ist schneller, als
> jeden Befehl über ein separates `ssh` zu senden, und genau so sollte man in der CKS-Prüfung arbeiten. Den Namen des
> control-plane Nodes sehen wir über `kubectl get no`:
>
> ```bash
> kubectl get no
> ssh <Node-Name-aus-der-Ausgabe>
> sudo -i
> ```
>
> Prüfungen und Artefakte: Der Checker liest die Artefakte von der **Arbeitsmaschine** (`worker`), aus
> `/var/work/tests/artifacts/<Nummer>/`, daher verlassen wir nach den Änderungen auf dem Node die Sitzung (`exit`, `exit`) und
> speichern das Artefakt mit einem kurzen Befehl vom `worker`. Lege dafür einmal den Node-Namen fest:
>
> ```bash
> CP=<Node-Name-aus-der-Ausgabe>
> mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6,7,9,10}
> ```
>
> Artefakte werden nur für die Überprüfung des Labs benötigt: In der CKS-Prüfung gibt es sie nicht, dort genügen Befehle auf dem
> Node und eine flüchtige Prüfung des Ergebnisses. Die Befehle speichern die Ausgabe in einer Datei (`>`), den Inhalt sehen wir
> separat über `cat <Datei>` - das erwartete Ergebnis steht in den Kommentaren `# ...` unter dem Block.
>
> Für den Docker-Host melden wir uns genauso an: `ssh docker-host`, dann `sudo -i`.

## 1. Unnötigen systemd-Dienst deaktivieren

Der Dienst `cks-lab105-unused.service` wird für Kubernetes nicht benötigt und vergrößert die Angriffsfläche.
Wir stoppen ihn und verbieten den Autostart.

Auf der control-plane:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-unused.service
systemctl is-enabled cks-lab105-unused.service   # disabled
systemctl is-active cks-lab105-unused.service    # inactive
exit
exit
```

Artefakt (auf `worker`):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-unused.service; systemctl is-active cks-lab105-unused.service' \
  | xargs > /var/work/tests/artifacts/1/service.txt
# disabled inactive
```

## 2. Unnötigen TCP/8080 schließen

Der Port 8080 wird absichtlich vom Dienst `cks-lab105-port.service` geöffnet; weder die
control-plane noch das kubelet brauchen ihn. Wir stoppen und deaktivieren den Dienst - beide Aktionen sind Pflicht,
sonst kehrt der Listener nach einem reboot zurück, selbst wenn der Port jetzt geschlossen ist.

Auf der control-plane:

```bash
ssh "$CP"
sudo -i
systemctl disable --now cks-lab105-port.service
ss -ltn | grep 8080     # leere Ausgabe - der Port ist geschlossen
exit
exit
```

Artefakte (auf `worker`):

```bash
ssh "$CP" 'systemctl is-enabled cks-lab105-port.service; systemctl is-active cks-lab105-port.service' \
  | xargs > /var/work/tests/artifacts/2/service.txt
# disabled inactive
# der Port wurde bereits auf dem Node geprüft (`ss -ltn | grep 8080` - leer), wir halten das Ergebnis fest:
echo 'tcp/8080: closed' > /var/work/tests/artifacts/2/port-8080.txt
```

## 3. Eingehenden Traffic mit UFW einschränken

Zuerst bestimmen wir die Topologie und die notwendigen Quellen. Das ist eine Ein-Node-control-plane,
die auch workloads ausführt. Der worker muss SSH- und API-Zugriff haben; Pod CIDR und der
Node selbst - API-Zugriff. Node-übergreifende kubelet/CNI flows gibt es hier nicht. Wir öffnen `22`/`6443` nicht für
`Anywhere`.

Auf `worker` sehen wir uns die benötigten Werte mit eigenen Augen an:

```bash
kubectl get no -o wide                                      # INTERNAL-IP des Nodes
kubectl get no "$CP" -o jsonpath='{.spec.podCIDR}{"\n"}'    # Pod CIDR
hostname -I                                                 # IP des worker
```

Wir schreiben sie in den preflight (setze deine Werte ein; die Zeile `role=` ist Pflicht):

```bash
WORKER_IP=<ip-worker>; NODE_IP=<internal-ip-des-nodes>; POD_CIDR=<pod-cidr>
printf 'role=control-plane,workload\nworker_ip=%s\nnode_ip=%s\npod_cidr=%s\n' \
  "$WORKER_IP" "$NODE_IP" "$POD_CIDR" > /var/work/tests/artifacts/3/preflight.txt
```

Baseline VOR UFW: Wir prüfen, dass TCP/10250 (kubelet HTTPS) jetzt tatsächlich erreichbar ist - ohne
dies beweist „blockiert“ nach UFW nichts, der Port könnte aus einem anderen Grund unerreichbar gewesen sein
(security group, routing). Der Checker gleicht separat mit seiner Baseline ab, aber auch dein
Eintrag wird gebraucht:

```bash
curl -ks -o /dev/null -w '%{http_code}\n' --max-time 3 "https://$NODE_IP:10250/healthz"
# 401 - der Port ist erreichbar (jedes 1xx-5xx, einschließlich 401/403, passt)
echo 'baseline kubelet 10250: CURL_EXIT=0 HTTPCODE=401' >> /var/work/tests/artifacts/3/preflight.txt
```

Wenn die Baseline unerreichbar ist (curl gab `000` zurück), korrigiere zuerst die Konnektivität, sonst ist das Ergebnis
nach UFW nicht überzeugend.

Die UFW-Regeln konfigurieren wir auf dem Node. Zuerst erlauben wir recovery und die benötigten Quellen, und erst
danach ändern wir den default. Die Werte `WORKER_IP`/`NODE_IP`/`POD_CIDR` nehmen wir aus `preflight.txt`
(setze deine ein):

```bash
ssh "$CP"
sudo -i
WORKER_IP=<worker_ip>; NODE_IP=<node_ip>; POD_CIDR=<pod_cidr>
ufw allow from "$WORKER_IP" to any port 22 proto tcp comment 'CKS105 worker SSH recovery'
ufw allow from "$WORKER_IP" to any port 6443 proto tcp comment 'CKS105 worker API'
ufw allow from "$NODE_IP" to any port 6443 proto tcp comment 'CKS105 node API'
ufw allow from "$POD_CIDR" to any port 6443 proto tcp comment 'CKS105 Pod API'
ufw allow in on lo comment 'CKS105 loopback'
ufw default allow outgoing
ufw default deny incoming
ufw --force enable
ufw status verbose
exit
exit
```

Artefakte (auf `worker`). `ufw show added` ist die normalisierte Darstellung der Regeln, die
du tatsächlich hinzugefügt hast (NICHT garantiert die ursprüngliche Form/Reihenfolge der Befehle - UFW normalisiert sie bei
der Anzeige). Die Prüfung vergleicht genau diese Liste mit der erwarteten allowlist - speichere sie
ebenfalls, das ist die zuverlässigste evidence des exact allow-set. Verwalte die Firewall nur über `ufw` -
bearbeite `/etc/ufw/before*.rules` oder `/etc/ufw/after*.rules` NICHT manuell, das sind
framework-Dateien mit allgemeinen default-Regeln und kein Ort für source-scoped rules; der Checker
gleicht ihren Hash mit der checker-owned bootstrap-Baseline ab und bemerkt eine direkte Bearbeitung.

```bash
ssh "$CP" 'sudo ufw status verbose; sudo ufw status' \
  > /var/work/tests/artifacts/3/ufw.txt
ssh "$CP" 'sudo ufw show added' \
  >> /var/work/tests/artifacts/3/ufw.txt

cat > /var/work/tests/artifacts/3/recovery.txt <<'EOF'
# Bei Verlust der API aus der noch geöffneten SSH/console session ausführen:
sudo ufw disable
sudo ufw status verbose
# die engen allow rules korrigieren, source IP/CIDR prüfen
sudo ufw --force enable
# Wenn die Regeln vollständig beschädigt sind, nur über console/recovery channel:
sudo ufw --force reset
EOF
```

Wir prüfen, dass der Cluster gesund ist (vom `worker`):

```bash
kubectl get --raw=/readyz
kubectl get nodes
kubectl rollout status deployment/health-probe -n cks-105-health --timeout=60s
# Ein workload innerhalb des Clusters muss weiterhin DNS auflösen und den API server erreichen
# (UFW darf den Traffic Pod -> CoreDNS und Pod -> API nicht unterbrechen):
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default   # muss die Address-Zeile des Service kubernetes zurückgeben
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz   # jeder Code außer 000

# Ein unerwünschter worker -> kubelet flow darf keine HTTP response liefern.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000 - transport deny
```

Obligatorischer vollständiger E2E retest NACH `ufw reload` - er beweist, dass das ruleset einen
reload übersteht und nicht nur unmittelbar nach `ufw enable` im Speicher funktioniert. Ohne diesen Schritt kann man
versehentlich ein falsches PASS unmittelbar nach dem enable erhalten:

```bash
ssh "$CP" 'sudo ufw reload'
sleep 2
kubectl get --raw=/readyz
kubectl get nodes
kubectl get pods -n kube-system -l k8s-app=calico-node
# Dieselben zwei Prüfungen des workloads wiederholen wir nach dem reload:
kubectl exec -n cks-105-health deploy/health-probe -- nslookup kubernetes.default
kubectl exec -n cks-105-health deploy/health-probe -- curl -ks -o /dev/null -w '%{http_code}\n' --max-time 5 https://kubernetes.default.svc/readyz
# Derselbe Vertrag wie vor dem reload: Der worker erreicht das kubelet weiterhin nicht.
curl -ksS -o /dev/null -w 'kubelet_http=%{http_code}\n' --connect-timeout 2 --max-time 3 \
  "https://${NODE_IP}:10250/healthz"
# kubelet_http=000
```

Prüfung declared vs effective: `ufw show added` ist eine deklarative Liste, rekonstruiert aus den
`### tuple ###`-Metadaten, die ufw selbst in `user.rules` schreibt, wenn eine Regel über die CLI
hinzugefügt wird. Der echte Zustand des Kernels nach `ufw reload` ist dagegen das, was
`ufw show user-rules` zeigt. Vergleiche nicht nur die ANZAHL der Zeilen, sondern auch ihren INHALT
(source/port/proto): `ufw-user-input` muss loopback (all, lo) und vier tcp
dpt:22/6443 Regeln mit exakten source-Adressen zeigen, und `ufw6-user-input` - GENAU eine Zeile, dasselbe
loopback ACCEPT für v6 (`ufw allow in on lo` ist eine Regel nach Interface ohne explizite IP,
daher erzeugt ufw immer eine v4- und eine v6-Version). Jede ANDERE/zusätzliche Zeile dort ist
ein fremder bypass:

```bash
ssh "$CP" 'sudo ufw show user-rules'
```

In der Ausgabe müssen `Status: active`, `Default: deny (incoming)` und source-scoped rules stehen -
sowohl in `ufw status verbose` als auch in der deklarativen Liste `ufw show added`. Schließe die
ursprüngliche SSH session nicht, bis `/readyz`, nodes, calico-node, workload (einschließlich Pod DNS vor und
nach dem reload) und beide negativen Prüfungen `10250` (vor und nach `ufw reload`, mit demselben
CURL_EXIT/HTTPCODE-Vertrag) das erwartete Ergebnis geliefert haben.

## 4. Kubeconfig des Administrators schützen

`/etc/kubernetes/admin.conf` enthält ein cluster-admin credential. Die Datei darf nur von
root gelesen werden.

Auf der control-plane:

```bash
ssh "$CP"
sudo -i
chown root:root /etc/kubernetes/admin.conf && chmod 600 /etc/kubernetes/admin.conf
stat -c '%U %G %a' /etc/kubernetes/admin.conf   # root root 600
exit
exit
```

Artefakt (auf `worker`):

```bash
ssh "$CP" "stat -c '%U %G %a' /etc/kubernetes/admin.conf" \
  > /var/work/tests/artifacts/4/admin-conf.txt
# root root 600
```

## 5. Direkten root login per SSH verbieten

Wir ändern die Konfiguration, prüfen die Syntax vor dem reload und wenden sie an, ohne die aktuelle
Sitzung abzubrechen.

Auf der control-plane:

```bash
ssh "$CP"
sudo -i
sed -i -E 's/^[[:space:]]*PermitRootLogin[[:space:]]+.*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -qE '^[[:space:]]*PermitRootLogin[[:space:]]+' /etc/ssh/sshd_config || echo 'PermitRootLogin no' >> /etc/ssh/sshd_config
sshd -t && systemctl reload ssh
```

Die aktuelle Sitzung bricht bei `reload ssh` nicht ab. Aber während des Neustarts von sshd kann eine neue
Verbindung zur control-plane 1-2 Sekunden lang `Connection refused` erhalten - das ist
normal und bedeutet nicht, dass die Konfiguration kaputt ist (sie wurde bereits von `sshd -t` geprüft), wiederhole
einfach den Befehl.

`sshd -T` ohne connection context wendet `Match`-Blöcke überhaupt nicht an - die man-Seite `sshd(8)`
sagt ausdrücklich, dass `Match` im test mode nur angewendet wird, wenn `-C` übergeben wurde. Daher
prüfen wir über `-C` und simulieren eine echte root-Verbindung vom worker (die Adressen nehmen wir aus
`preflight.txt` aus Aufgabe 3):

```bash
sshd -T -C 'user=root,addr=<worker_ip>,laddr=<node_ip>,lport=22' | grep -i permitrootlogin
# permitrootlogin no
exit
exit
```

Artefakt (auf `worker`, nach einer Pause von ein paar Sekunden):

```bash
# WORKER_IP und NODE_IP - dieselben Werte wie in Aufgabe 3
ssh "$CP" "sudo sshd -T -C 'user=root,addr=${WORKER_IP},laddr=${NODE_IP},lport=22' | awk '\$1 == \"permitrootlogin\" {print \"PermitRootLogin \" \$2}'" \
  > /var/work/tests/artifacts/5/sshd.txt
# PermitRootLogin no
```

## 6. Unsicheren Zugriff auf den Docker daemon auf `docker-host` schließen

TCP/2375 hat weder TLS noch Authentifizierung: Der Zugriff darauf ist praktisch gleichbedeutend mit root-Zugriff
auf den Host. Wir entfernen das Lern-systemd-override mit dem TCP-Listener, setzen den Eigentümer des unix-Sockets
über ein socket override und entfernen `developer` aus der Gruppe `docker`.

Wir wenden die Änderungen über ein vollständiges `daemon-reload` + restart **beider** units an - das ist ein
obligatorischer Schritt und nicht nur „die Konfiguration neu einlesen“: Ohne echten restart kann man die Prüfung
versehentlich „bestehen“, wenn Docker einfach aufgehört hat zu antworten (dann ist TCP/2375 nicht deshalb zu, weil
`-H tcp://` entfernt wurde, sondern weil der daemon überhaupt nicht läuft).

Auf `docker-host`:

```bash
ssh docker-host
sudo -i
rm -f /etc/systemd/system/docker.service.d/10-cks-lab105-tcp.conf
install -d -m 0755 /etc/systemd/system/docker.socket.d
printf '[Socket]\nSocketGroup=root\nSocketMode=0660\n' > /etc/systemd/system/docker.socket.d/10-cks-lab105-socket.conf
gpasswd -d developer docker || true
systemctl daemon-reload
systemctl restart docker.socket
systemctl restart docker.service
chown root:root /var/run/docker.sock && chmod 660 /var/run/docker.sock
```

Positive control: Docker läuft nach dem restart tatsächlich (nicht nur, dass er 2375 nicht abhört - er
muss über den unix-Socket vollwertig funktionieren):

```bash
systemctl is-active docker.service docker.socket   # active / active
docker version && docker info >/dev/null
```

Prüfung der persistenten Konfiguration - die effective unit enthält kein `-H tcp://`, und das socket override setzt
tatsächlich die benötigten Werte (und stimmt nicht nur vorübergehend mit ihnen überein):

```bash
systemctl cat docker.service | grep -c "H tcp://"   # 0
systemctl cat docker.socket                          # ... SocketGroup=root ... SocketMode=0660 ...
```

Der Vertrag der Aufgabe ist weiter gefasst als der Port 2375: Die Docker API darf auf keinem Port TCP abhören, und
`docker.socket` darf kein TCP `ListenStream` enthalten:

```bash
ss -ltnp | grep dockerd                        # leere Ausgabe (der von systemd gehaltene TCP-Socket von docker.socket wird von der nächsten Zeile geprüft)
systemctl cat docker.socket | grep ListenStream # nur /run/docker.sock (und ein leerer Reset)
stat -c '%U %G %a' /var/run/docker.sock         # root root 660
sudo -u developer docker ps                     # permission denied
exit
exit
```

Artefakte (auf `worker`):

```bash
# der Port 2375 wurde bereits auf docker-host geprüft (`ss -ltnp | grep dockerd` - leer), wir halten das Ergebnis fest:
echo 'tcp/2375: closed' > /var/work/tests/artifacts/6/docker-tcp.txt
ssh docker-host "sudo stat -c '%U %G %a' /var/run/docker.sock" \
  > /var/work/tests/artifacts/6/docker-socket.txt
ssh docker-host 'if sudo -u developer docker ps >/dev/null 2>&1; then echo "developer docker ps: allowed"; else echo "developer docker ps: denied"; fi' \
  > /var/work/tests/artifacts/6/developer-access.txt
# tcp/2375: closed
# root root 660
# developer docker ps: denied
```

Starte nach Ausführung aller Schritte `check_result`.

## 7. Laden des Moduls `sctp` verbieten

`sctp` ist geladen, wird aber auf diesem Node weder von kubeadm noch von containerd noch von Calico benötigt. Wir versuchen,
das bereits geladene Modul zu entladen, und blockieren dann in jedem Fall das erneute Laden sowohl
über `blacklist` als auch über ein `install` override. Beide Direktiven wirken auf Ebene von
`modprobe` (alias resolution und ein explizites `modprobe sctp`) und beseitigen den üblichen Ladepfad;
sie ersetzen kein kernel-level enforcement (`insmod` fügt das Modul direkt über einen syscall ein
und liest `modprobe.d` nicht, und `modprobe --ignore-install` kann `install` bei vorhandenem
root-Zugriff auf dem Host umgehen) - für dieses Lab ist wichtig, genau den erwarteten Autoload-Pfad zu beseitigen und nicht
einen Schutz vor einem Benutzer zu gewährleisten, der bereits root auf dem Node hat.

**`modprobe -r sctp` kann auf einem bereits laufenden Cluster scheitern** - das ist zu erwarten und
kein Fehler des Teilnehmers. Protokoll-Kernelmodule (darunter `sctp`) erhalten eine persistente
per-network-namespace-Referenz (`try_module_get` in der pernet-Initialisierung) für jedes netns,
das zum Zeitpunkt des Ladens des Moduls bereits existierte - auf diesem Node laufen bereits Pods
(calico, coredns, kube-system), daher kann `sctp` im Zustand `in use` mit
von null verschiedenem refcount und LEEREM `/sys/module/sctp/holders` bleiben (das heißt, es wird nicht von einem anderen Modul gehalten -
es gibt nichts, was rekursiv entladen werden könnte). Das lässt sich nicht beheben, ohne alle diese Pods zu stoppen, was nicht
zur Aufgabe gehört. Wichtig und geprüft ist genau das, was unter Kontrolle des Teilnehmers liegt:
Das Modul darf nicht NEU geladen werden können.

Auf der control-plane:

```bash
ssh "$CP"
sudo -i
modprobe -r sctp || true
printf 'blacklist sctp\ninstall sctp /bin/true\n' > /etc/modprobe.d/60-cks-sctp.conf
lsmod | grep sctp                       # kann leer oder nicht leer sein - beide Varianten sind zulässig
modprobe --show-config | grep sctp      # install sctp /bin/true und blacklist sctp
exit
exit
```

Artefakt (auf `worker`): der aktuelle Zustand (`absent` oder `present`) und das override in der effective
modprobe config:

```bash
ssh "$CP" '
{
  if lsmod | grep -q sctp; then echo "lsmod: present"; else echo "lsmod: absent"; fi
  modprobe --show-config | grep sctp
}' > /var/work/tests/artifacts/7/sctp.txt
# lsmod: absent   (oder lsmod: present - beide Varianten sind zulässig, siehe oben)
# install sctp /bin/true
```

## 8. `protectKernelDefaults` und sichere sysctl

Zuerst korrigieren wir sysctl - `protectKernelDefaults: true` lässt das kubelet **beim
Start abstürzen**, wenn die aktuellen Kernelwerte nicht mit seinen Erwartungen übereinstimmen, daher
müssen die sysctl angewendet sein, bevor das kubelet neu gestartet wird.

Auf der control-plane:

```bash
ssh "$CP"
sudo -i
printf 'kernel.unprivileged_bpf_disabled = 1\nvm.overcommit_memory = 1\n' > /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl kernel.unprivileged_bpf_disabled vm.overcommit_memory
```

Jetzt aktivieren wir `protectKernelDefaults` in der kubelet-Konfiguration und starten den Dienst neu:

```bash
grep -q '^protectKernelDefaults:' /var/lib/kubelet/config.yaml \
  && sed -i 's/^protectKernelDefaults:.*/protectKernelDefaults: true/' /var/lib/kubelet/config.yaml \
  || echo 'protectKernelDefaults: true' >> /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet     # active
exit
exit
```

Der Node muss `Ready` bleiben (vom `worker`):

```bash
kubectl get no
```

Wenn das kubelet nach diesem Schritt nicht hochkommt, prüfe genau die Reihenfolge: Die sysctl müssen
angewendet sein (`sysctl --system`) und nicht nur in die Datei geschrieben, bevor das kubelet
sie beim Start prüft.

## 9. Überflüssige SUID-Binärdatei finden und entschärfen

`find` zeigt sowohl die System-SUID-Binärdateien (`sudo`, `passwd`, `mount` - wir fassen sie nicht an) als auch
die Lern-Binärdatei `/usr/local/bin/cks-lab105-suid-tool`, die keine Komponente von
Kubernetes auf diesem Node benötigt.

`/var/lib/containerd` ist aus der Ausgabe ausgeschlossen: Seine overlayfs snapshot-Pfade sind der Inhalt der
container image layers und keine auf dem Host installierten Binärdateien, und sie ändern sich bei jedem
pull/extract eines Images während des Labs, unabhängig von den Aktionen des Teilnehmers.

Das Artefakt `suid-before.txt` muss **vor** der Korrektur gespeichert werden (auf `worker`):

```bash
ssh "$CP" "sudo find / -xdev -perm -4000 -type f 2>/dev/null | grep -v '^/var/lib/containerd/'" \
  > /var/work/tests/artifacts/9/suid-before.txt
grep cks-lab105-suid-tool /var/work/tests/artifacts/9/suid-before.txt
```

Wir entfernen das SUID-Bit nur bei der Lerndatei (auf der control-plane) und stellen sicher, dass die
System-SUID-Binärdateien nicht angetastet wurden - `sudo`/`passwd` müssen das SUID-Bit behalten, sonst geht die grundlegende
Funktionalität des Betriebssystems kaputt:

```bash
ssh "$CP"
sudo -i
chmod u-s /usr/local/bin/cks-lab105-suid-tool
stat -c '%a' /usr/local/bin/cks-lab105-suid-tool   # 755
stat -c '%a %n' /usr/bin/sudo /usr/bin/passwd      # 4755 ...
exit
exit
```

Artefakt `suid-after.txt` (auf `worker`):

```bash
ssh "$CP" "stat -c '%a' /usr/local/bin/cks-lab105-suid-tool" \
  > /var/work/tests/artifacts/9/suid-after.txt
# 755
```

Starte nach Ausführung aller Schritte `check_result`.

## 10. Core dumps deaktivieren und SUID-Prozesse schützen

Ein core dump kann Secrets und Schlüssel aus dem Speicher des Prozesses zum Zeitpunkt des crash enthalten - er muss sowohl für
gewöhnliche als auch für SUID-Prozesse verboten werden. `fs.suid_dumpable` fügen wir in dieselbe Datei
`/etc/sysctl.d/99-kubernetes.conf` ein, die bereits in Aufgabe 8 erstellt wurde - wir erstellen keine separate,
konfligierende Konfiguration.

Unter Ubuntu **garantieren** `ulimit -c 0` und `fs.suid_dumpable=0` nicht das Fehlen eines core dump:
`man 5 core` dokumentiert ausdrücklich, dass `RLIMIT_CORE` vom Kernel ignoriert wird, wenn
`kernel.core_pattern` den dump über eine pipe (`|program`) an einen userspace-Handler leitet.
Ubuntu ist standardmäßig genau so konfiguriert - den crash fängt Apport ab und speichert ihn in
`/var/lib/apport/coredump/` UNABHÄNGIG von `ulimit -c` des Prozesses. Der einzige zuverlässige
Weg ist, `kernel.core_pattern` selbst auf einen garantiert nicht funktionierenden Handler zu überschreiben.

Wir begrenzen auch die Größe des core dump auf Ebene der Prozesslimits - das ist ein vom
`suid_dumpable`/`core_pattern` getrennter Mechanismus (soft limit für gewöhnliche crashes bei klassischem
dateibasiertem Schreiben, falls dieses jemals wiederhergestellt wird).

Auf der control-plane:

```bash
ssh "$CP"
sudo -i
printf 'fs.suid_dumpable = 0\nkernel.core_pattern = |/bin/false\n' >> /etc/sysctl.d/99-kubernetes.conf
sysctl --system
sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern   # 0 / |/bin/false
printf '* hard core 0\n* soft core 0\n' >> /etc/security/limits.conf
```

`limits.conf` wird über PAM auf neue login-Sitzungen angewendet und nicht auf bereits geöffnete shells -
wir prüfen ausdrücklich in einer neuen Sitzung:

```bash
su - ubuntu -c 'ulimit -c'      # 0
exit
exit
```

Artefakt `coredump.txt` (auf `worker`). Enthält einen controlled crash probe: Wir bestätigen, dass
nach einem echten `SIGSEGV` KEIN NEUER retained core dump in den Apport-Verzeichnissen
(`/var/lib/apport/coredump`, `/var/crash`) erscheint:

```bash
ssh "$CP" "sysctl -n fs.suid_dumpable; cat /proc/sys/kernel/core_pattern; sudo su - ubuntu -c 'ulimit -c'" \
  > /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" "cat /etc/sysctl.d/99-kubernetes.conf; cat /etc/security/limits.conf" \
  >> /var/work/tests/artifacts/10/coredump.txt
ssh "$CP" '
before_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
sh -c "kill -SEGV \$\$" || true
sleep 2
after_count=$(sudo find /var/lib/apport/coredump /var/crash -type f 2>/dev/null | wc -l)
if [ "$after_count" -le "$before_count" ]; then
  echo "crash-probe: no new retained core dump"
else
  echo "crash-probe: NEW core dump appeared after SIGSEGV"
fi
' >> /var/work/tests/artifacts/10/coredump.txt
# crash-probe: no new retained core dump
```

Starte nach Ausführung aller Schritte `check_result`.
