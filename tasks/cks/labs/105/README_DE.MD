[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 105 - System Hardening des Betriebssystems und Sicherheit des Docker daemon

## Ziel

In dieser CKS-Lab verkleinerst du die Angriffsfläche zweier Linux-Hosts. Auf der Kubernetes
control-plane musst du überflüssige Dienste deaktivieren, einen offenen Port schließen, die Firewall konfigurieren,
die kubeconfig schützen und den direkten root login per SSH verbieten. Auf dem separaten `docker-host`
müssen drei gefährliche Einstellungen des Docker daemon beseitigt werden: die TCP API ohne TLS, der Zugriff auf
`docker.sock` über die Gruppe `docker` und der Zugriff des Benutzers `developer` auf diesen Socket.

Diese Lernumgebung ist absichtlich unsicher aufgebaut. Übertrage die Ausgangseinstellungen nicht
nach production: Die Docker API auf TCP/2375 ohne TLS gibt jedem, der sich mit dem Port
verbinden kann, remote root-Zugriff.

## Prüfe dich vor dem Start

<details>
<summary>1. Wie unterscheidet sich `systemctl disable` von `systemctl stop`, und warum braucht Aufgabe 1 beide?</summary>

`stop` stoppt den bereits laufenden Prozess jetzt sofort, beeinflusst aber nicht den Autostart beim nächsten Systemstart. `disable` entfernt den Dienst aus dem Autostart (die unit-Datei ist nicht mehr an das target gebunden), stoppt aber den bereits laufenden Prozess nicht. Um die Angriffsfläche vollständig zu schließen, braucht man beides - sonst läuft der Dienst entweder jetzt weiter oder startet nach einem reboot erneut.
</details>

<details>
<summary>2. Warum ist die TCP Docker API ohne TLS (`-H tcp://0.0.0.0:2375`) gleichbedeutend mit remote root-Zugriff?</summary>

Der Docker daemon läuft mit root-Rechten, und seine API hat ohne TLS client certificates keine built-in authentication. Jeder, der sich über das Netzwerk mit diesem Port verbinden kann, kann einen beliebigen container mit `--privileged` und gemountetem host filesystem starten - und so die volle Kontrolle über den Host erlangen, an SSH und allen anderen Zugriffskontrollmechanismen vorbei.
</details>

<details>
<summary>3. Warum ist `chmod 600` für die kubeconfig wichtig, auch wenn die Datei über das Dateisystem ohnehin nur für root zugänglich ist?</summary>

`/etc/kubernetes/admin.conf` enthält ein client certificate mit `cluster-admin`-Rechten - wenn der Modus der Datei zu weit ist (zum Beispiel `644`, für alle lesbar), kann JEDER Benutzer auf diesem Node, selbst ohne sudo, die credential lesen und vollen administrativen Zugriff auf den Cluster aus der Ferne erhalten, ohne dass eine privilege escalation auf dem Node selbst nötig wäre.
</details>

<details>
<summary>4. Warum kann ein core dump eines Prozesses ein Secret preisgeben, auch wenn das Secret selbst nie auf die Platte geschrieben wurde?</summary>

Ein core dump ist ein Speicherabbild des Prozesses zum Zeitpunkt des crash, das entschlüsselte Werte von Variablen, private keys und im Klartext gehaltene tokens enthalten **kann**. Es ist nicht garantiert der gesamte Speicher des Prozesses: Die Menge der Mappings hängt von `/proc/<pid>/coredump_filter` ab, und einzelne Bereiche können ausgeschlossen sein, zum Beispiel über `MADV_DONTDUMP`. Deshalb kann ein crash dump selbst dann, wenn die Anwendung das Secret nie explizit in eine Datei schreibt, die in den eingeschlossenen Mappings vorhandenen Secrets in einer lesbaren Datei auf der Platte ablegen.
</details>

## Bezug zum Kurs

- [Kapitel 14. Minimierung des footprint des Host-Betriebssystems und Sicherheit des runtime-daemon](../../course/14/de.md)
- [Kapitel 15. Least-privilege auf dem Host und Minimierung des externen Zugriffs](../../course/15/de.md)
- [CKA: systemd, Dienste und Linux](../../../cka/course/00-5-linux/de.md)
- [CKA: Container und runtime](../../../cka/course/00-4-containers/de.md)

## Infrastruktur

Die Umgebung wird über Terragrunt in AWS `eu-central-1` ausgerollt:

| Komponente | Zweck |
|---|---|
| `vpc` | VPC `10.10.0.0/16` mit zwei öffentlichen Subnetzen |
| `ssh-keys` | SSH-Schlüssel für interne Verbindungen |
| `k8s-1` | Ein-Node-kubeadm-Cluster Kubernetes `1.36.0`, containerd, Calico; das ist die Ziel-control-plane |
| `docker-host` | separates Ubuntu 22.04 mit Docker und absichtlich unsicherer Konfiguration |
| `worker` | Arbeitsmaschine mit `kubectl`, SSH-Konfiguration und `check_result` |

`worker` hat SSH-Zugriff auf die control-plane über ihren Kubernetes node name und auf den separaten
Host über den Namen `docker-host`. Docker ist nicht die runtime des Kubernetes-Clusters: Die
Konfiguration aus Aufgabe 6 ist auf `docker-host` isoliert.

## Bereitstellung

```bash
TASK=105 make run_cks_task
```

Verbinde dich mit `worker` (der kubectl-Kontext ist bereits eingerichtet), sieh dir den Namen des control-plane-
Nodes an und melde dich auf den Hosts an:

```bash
kubectl get no
ssh <Node-Name-aus-der-Ausgabe>
ssh docker-host
```

Nützliche Befehle:

```bash
time_left
check_result
```

Speichere die Prüf-artifacts in `/var/work/tests/artifacts/<Nummer>/`. Kubernetes-Manifeste
müssen für diese Lab nicht erstellt werden.

## Aufgaben

---
| **1** | **Überflüssigen Dienst deaktivieren** |
| :---: | :--- |
| Was wir tun | Deaktiviere und stoppe auf der control-plane `cks-lab105-unused.service`. Der Dienst wird für den Betrieb von Kubernetes nicht benötigt und darf nach einem reboot nicht starten. |
| Abnahmekriterien | `systemctl is-enabled cks-lab105-unused.service` gibt `disabled` zurück, `systemctl is-active` - `inactive`; in `/var/work/tests/artifacts/1/service.txt` steht die Zeile `disabled inactive`. |

<details>
<summary>💡 Hinweis zu Aufgabe 1</summary>

Reihenfolge der Befehle: `sudo systemctl stop cks-lab105-unused.service && sudo systemctl disable cks-lab105-unused.service` - beide Schritte sind nötig, keiner ersetzt den anderen (siehe Frage 1 im Selbsttest-Abschnitt oben). Das artifact muss genau die Zeile "disabled inactive" enthalten (in dieser Reihenfolge, durch ein Leerzeichen getrennt) - prüfe das Format vor dem Speichern.
</details>

---
| **2** | **Unnötigen offenen Port schließen** |
| :---: | :--- |
| Was wir tun | Beseitige auf der control-plane den von `cks-lab105-port.service` erzeugten Listener auf TCP/8080. Deaktiviere und stoppe den Dienst (beide Aktionen sind Pflicht - siehe Frage 1 im Selbsttest-Abschnitt); weder die control-plane noch das kubelet brauchen ihn. |
| Abnahmekriterien | `ss -ltn` zeigt TCP/8080 nicht; `systemctl is-enabled cks-lab105-port.service` gibt `disabled` zurück, `systemctl is-active` - `inactive`; `/var/work/tests/artifacts/2/service.txt` enthält die Zeile `disabled inactive`; `/var/work/tests/artifacts/2/port-8080.txt` enthält `tcp/8080: closed`. |

<details>
<summary>💡 Hinweis zu Aufgabe 2</summary>

Finde zuerst heraus, welcher Prozess den Port belegt (`sudo ss -ltnp | grep 8080`), um sicherzustellen, dass es tatsächlich `cks-lab105-port.service` ist und nichts anderes. Den Port über die Firewall (Aufgabe 3) zu schließen, reicht für diese Aufgabe nicht - der Test prüft, dass der Listener SELBST nicht vorhanden ist und nicht nur von außen blockiert wird.
</details>

---
| **3** | **Eingehenden Traffic per Firewall einschränken** |
| :---: | :--- |
| Was wir tun | • Halte vor dem Aktivieren von UFW die Rolle des Nodes, die worker source IP, die node InternalIP und `spec.podCIDR` fest.<br/>• **Obligatorische Baseline vor der Firewall:** Halte einen Baseline-Probe auf TCP/10250 (kubelet HTTPS endpoint) vom worker aus fest - `curl` mit echtem `CURL_EXIT`/`HTTPCODE`, der die Netzwerkerreichbarkeit des Ports beweist (jedes 1xx-5xx, einschließlich 401/403, gilt als Erreichbarkeit - die kubelet API hat tatsächlich geantwortet). Ohne diesen Schritt lässt sich das post-hardening "blockiert" nicht von einem fremden Ausfall (security group, routing) unterscheiden, der den Port schon vor UFW blockiert hat. Zusätzlich zu deinem Eintrag gleicht der Checker dies unabhängig mit seiner eigenen bootstrap-Baseline ab, die VOR der Ausgabe der Lab in einem geschützten Verzeichnis `/var/lib/cks-lab105-checker` festgehalten wurde (`0711 root:root`, getrennt von `/var/work/tests`, das standardmäßig für alle beschreibbar ist).<br/>• Topologie: Ein-Node-control-plane + workload node. Es werden genau fünf Regeln benötigt: loopback, SSH recovery vom worker, API `6443/tcp` vom worker, vom Node selbst und vom Pod CIDR. etcd/scheduler/controller-manager verwenden lokale flows, node-übergreifende CNI/kubelet flows gibt es in dieser Topologie nicht.<br/>• Verwalte die Firewall nur mit dem Befehl `ufw` (allow/deny/reject/limit/route, dann enable/reload). Bearbeite `/etc/ufw/before*.rules`, `after*.rules`, `user.rules`, `user6.rules` nicht manuell: Die framework-Dateien (before/after) werden per Hash mit der bootstrap-Baseline abgeglichen, und `user.rules`/`user6.rules` (wohin ufw deine Regeln schreibt) werden über den tatsächlichen Zustand des Kernels (`ufw show user-rules`) geprüft und nicht nur über die Datei.<br/>• Füge source-scoped allow rules vor `ufw default deny incoming` hinzu. Verwende keine breiten `ALLOW Anywhere` und füge keine anderen Regeln über diese fünf hinaus hinzu (loopback + 4 source-scoped), einschließlich deny/reject/route.<br/>• Aktiviere UFW und speichere in `/var/work/tests/artifacts/3/`: `ufw status`, `ufw show added` (normalisierte Darstellung der hinzugefügten Regeln - nicht unbedingt in der ursprünglichen Form/Reihenfolge der Befehle), preflight (einschließlich der Baseline TCP/10250) und recovery-Befehle.<br/>• **Obligatorischer retest nach `ufw reload`:** Führe `sudo ufw reload` aus und wiederhole ALLE dieselben Prüfungen (readyz, node Ready, calico-node Ready, Pod DNS, Pod→API, worker→kubelet:10250 deny, effective UFW rule count). Eine Regel, die nur unmittelbar nach dem enable im Speicher funktioniert, einen reload aber nicht übersteht, gilt nicht als korrekte Lösung. |
| Abnahmekriterien | • **Baseline TCP/10250:** Die checker-owned bootstrap-Baseline (vor der Ausgabe der Lab in `/var/lib/cks-lab105-checker` festgehalten, Verzeichnis `0711 root:root` außerhalb von `/var/work/tests`, Datei `0444 root:root`) bestätigt die ursprüngliche Erreichbarkeit von TCP/10250; dein eigener Baseline-Probe vor UFW ist gespeichert und zeigt echte Netzwerkerreichbarkeit (`CURL_EXIT=0`, HTTP `1xx-5xx`). Wenn der Port bereits in der Baseline nicht erreichbar ist, lautet das Ergebnis der Aufgabe `inconclusive` und nicht PASS.<br/>• **UFW und exakte Regelmenge:** UFW active, default-deny; `ufw show added` enthält GENAU fünf Zeilen: loopback + `worker_ip`→`22/tcp` + `worker_ip`→`6443/tcp` + `node_ip`→`6443/tcp` + `pod_cidr`→`6443/tcp`, ohne eine einzige überflüssige Regel IRGENDEINER Aktion (`allow`/`deny`/`reject`/`limit`/`route`) und ohne dass eine der fünf fehlt.<br/>• **Framework-Dateien:** Der Hash von `/etc/ufw/before*.rules`/`after*.rules` unterscheidet sich nicht von der checker-owned bootstrap-Baseline (Regeln werden nur über `ufw` hinzugefügt, framework-Dateien werden nicht manuell bearbeitet).<br/>• **Tatsächlicher Kernel-Zustand:** `sudo ufw show user-rules` (echte `ufw-user-*` chains über `iptables -L`) stimmt semantisch mit den erwarteten fünf Regeln überein - geprüft werden nicht nur die Anzahl, sondern source/interface/protocol/port JEDER Regel, sowohl nach `enable` als auch nach `reload`. `ufw6-user-input` bleibt GENAU mit einer Zeile - der v6-Version des loopback ACCEPT (`ufw allow in on lo` erzeugt gleichzeitig eine v4- und eine v6-Regel, da es sich um eine Regel nach Interface ohne explizite IP handelt; nicht "völlig leer"). Das fängt direktes Bearbeiten von `user.rules`/`user6.rules` ohne tuple metadata (das sich weder in `ufw show added` noch im Hash von `before/after` niederschlägt) und die Erweiterung einer bereits deklarierten Regel (zum Beispiel `node_ip`→`6443/tcp`, heimlich durch `node_ip`→`any` ersetzt) ohne Änderung der Zeilenanzahl.<br/>• **Gesundheit des Clusters:** `/readyz=ok`; der erwartete Node und alle `calico-node` Pods bleiben `Ready`; `health-probe` bleibt Ready, löst DNS auf und erreicht den Kubernetes Service.<br/>• **Blockierung des kubelet:** Nach UFW erreicht der worker das kubelet `10250` nicht (`HTTPCODE=000`, transport deny) - gerade als Regression gegenüber der nachgewiesenen Baseline.<br/>• **Retest nach reload:** **alle dieselben Prüfungen bestehen erneut nach explizitem `sudo ufw reload`**: readyz/node/calico-node/DNS/Pod→API bleiben gesund, worker→kubelet:10250 bleibt mit demselben deny-Vertrag blockiert wie vor dem reload, und die tatsächliche Regelanzahl im Kernel stimmt wieder mit der deklarativen überein.<br/>• **Artifacts:** Das artifact enthält recovery-Befehle (`ufw disable`, Prüfung, Korrektur und erneutes Aktivieren). |

<details>
<summary>💡 Hinweis zu Aufgabe 3</summary>

Der gefährlichste Fehler hier ist, `ufw enable` (default-deny) auszuführen, BEVOR du die allow-Regel für SSH von der worker IP hinzugefügt hast. Die Reihenfolge muss sein: zuerst alle nötigen `ufw allow from <IP> to any port <port>`, erst danach `ufw --force enable`. Lasse die aktuelle SSH-Sitzung während der gesamten Arbeit mit der Firewall geöffnet - wenn du den Zugriff verlierst, verbindet sich eine zweite Sitzung für recovery nicht (siehe Warnung unten). Vergiss die Baseline-Probe TCP/10250 VOR dem Aktivieren von UFW nicht - ohne sie beweist das post-hardening "blockiert" nichts: Der Port konnte schon früher aus einem völlig anderen Grund unerreichbar sein (zum Beispiel AWS security group), und dann hat UFW damit überhaupt nichts zu tun; außerdem hat der Checker seine eigene Baseline, die schon vor der Ausgabe der Lab in einem separaten geschützten Verzeichnis festgehalten wurde, daher lässt sich dieser Eintrag nicht nachträglich fälschen. Prüfe das allow-set strikt über `sudo ufw show added` (nicht nur `ufw status`) - dort müssen GENAU fünf Zeilen stehen, keine überflüssige (keine breiten `ALLOW Anywhere`, keine zusätzlichen Ports, und das betrifft JEDE Aktion - `allow`, `deny`, `reject`, `limit`, `route`, nicht nur neue allow) und keine fehlende. Verwalte die Firewall nur über den Befehl `ufw` - bearbeite `/etc/ufw/before*.rules`/`after*.rules`/`user.rules`/`user6.rules` nicht manuell: Die framework-Dateien werden per Hash abgeglichen, und den tatsächlichen Zustand von `user.rules`/`user6.rules` prüft der Checker direkt über die echten iptables-Regeln in den `ufw-user-*` chains (`sudo ufw show user-rules`), daher wird selbst eine Änderung von `user.rules` ohne korrekte `### tuple ###`-Kommentare nach `ufw reload` entdeckt. Und vergiss nicht, am Ende `sudo ufw reload` auszuführen und alle Prüfungen zu wiederholen - eine Regel, die nur unmittelbar nach `enable` funktioniert, aber `reload` nicht übersteht, wird nicht gewertet.
</details>

> **Recovery zuerst.** Lasse die aktuelle SSH-Sitzung bis zur vollständigen Prüfung geöffnet. Wenn die API
> verschwindet, führe aus ihr `sudo ufw disable` aus, korrigiere die allow rules und aktiviere erst dann
> die Firewall erneut. Wenn SSH bereits verloren ist, verwende den console/recovery channel des Providers;
> versuche nicht, die Situation mit einem breiten `allow from any` zu "heilen".
>
> **Geltungsgrenze.** Diese UFW allowlist ist nur für die Ein-Node-fixture ausgelegt.
> Sie darf nicht buchstäblich in einen multi-node Cluster übertragen werden: Vor default-deny müssen
> kubelet- und node-übergreifende Flows, CNI overlay, BGP/VXLAN/WireGuard, LoadBalancer/NodePort sowie
> provider firewall/security groups für die konkrete Topologie inventarisiert werden.
>
> **Lab-specific exception: UFW auf einem Calico node.** Die offizielle Calico-Dokumentation zu den
> Anforderungen empfiehlt ausdrücklich, firewalld und andere iptables manager auf
> Calico-Nodes zu deaktivieren, weil sie mit den Regeln kollidieren können, die Calico selbst setzt.
> UFW ist ein ebensolcher iptables/nftables manager. Diese Lab behält UFW absichtlich auf der
> control-plane, um host firewall hardening zu üben (eine eigene Fähigkeit im Programm der Prüfung
> CKS), und nicht als empfohlenen Weg, Calico in production mit einer host firewall zu vereinbaren - dafür
> bietet Calico sein eigenes `HostEndpoint`/`GlobalNetworkPolicy`. Genau deshalb verlangt die Aufgabe
> explizit die kontrollierte Abfolge baseline → `ufw enable` → retest mit
> der Prüfung, dass `calico-node` und die gesamte Kubernetes-Konnektivität intakt bleiben (siehe
> `ADVERSARIAL_ACCEPTANCE_STANDARD.md`).

---
| **4** | **Rechte der kubeconfig korrigieren** |
| :---: | :--- |
| Was wir tun | Schütze auf der control-plane `/etc/kubernetes/admin.conf`, das die cluster-admin credential enthält: Eigentümer und Gruppe müssen `root:root` sein, der Modus - `600`. |
| Abnahmekriterien | `stat -c '%U %G %a' /etc/kubernetes/admin.conf` gibt `root root 600` zurück; derselbe Wert ist in `/var/work/tests/artifacts/4/admin-conf.txt` gespeichert. |

<details>
<summary>💡 Hinweis zu Aufgabe 4</summary>

Ein Befehl löst alles: `sudo chown root:root /etc/kubernetes/admin.conf && sudo chmod 600 /etc/kubernetes/admin.conf`. Prüfe dich direkt danach - wenn du selbst diese Datei als Benutzer `ubuntu` über `KUBECONFIG=/etc/kubernetes/admin.conf` verwendest, verschwindet der Lesezugriff, und das ist ERWARTET - verwende für die tägliche Arbeit eine separate kubeconfig.
</details>

---
| **5** | **Root login per SSH verbieten** |
| :---: | :--- |
| Was wir tun | Setze auf der control-plane `PermitRootLogin no` in `/etc/ssh/sshd_config`, prüfe die Syntax über `sshd -t` und lade SSH sicher neu. Prüfe den effektiven Wert gerade für die root-Verbindung mit dem Befehl `sshd -T -C "user=root,addr=<deine IP>,laddr=<IP des Nodes>,lport=22"` und nicht einfach mit `sshd -T` ohne connection context. |
| Abnahmekriterien | Der effektive Wert von `permitrootlogin` für den root connection context ist gleich `no`; `/var/work/tests/artifacts/5/sshd.txt` enthält `PermitRootLogin no`. |

<details>
<summary>💡 Hinweis zu Aufgabe 5</summary>

`sshd -T` zeigt die EFFEKTIVE Konfiguration, aber OHNE connection context (`-C`) werden `Match`-Blöcke (`Match User`/`Match Address`/`Match Group` und ähnliche) überhaupt nicht angewendet - die man-Seite `sshd(8)` sagt ausdrücklich, dass `Match`-Regeln im test mode angewendet werden "only when the connection parameters are supplied via one or more `-C` options". Daher kann `sshd -T` ohne `-C` `permitrootlogin no` aus dem Hauptblock der Konfiguration zeigen, obwohl ein spezifischerer `Match`-Block (zum Beispiel `Match Address <IP des Administrators>` oder `Match User root`) root login gerade für die reale Verbindung erlaubt. Prüfe über `sshd -T -C "user=root,addr=<IP>,laddr=<IP des Nodes>,lport=22"` - das simuliert eine REALE eingehende root-Verbindung und zwingt `sshd`, alle passenden `Match`-Blöcke anzuwenden, bevor es den resultierenden Wert zeigt. Lasse IMMER die aktuelle SSH-Sitzung vor `systemctl reload sshd` geöffnet und prüfe aus einer neuen Sitzung - nicht aus derjenigen, die bereits vor der Änderung authentifiziert war.
</details>

---
| **6** | **Unsicheren Zugriff auf den Docker daemon auf `docker-host` schließen** |
| :---: | :--- |
| Was wir tun | • Beende auf dem separaten `docker-host` die Veröffentlichung der Docker API auf TCP/2375: Entferne `-H tcp://...` aus dem Lern-systemd-override, behalte aber den Zugriff nur über den unix-socket.<br/>• Konfiguriere `/var/run/docker.sock` als `root:root` mit dem Modus `660`; für Beständigkeit nach einem restart setze dies über den override von `docker.socket`.<br/>• Entferne `developer` aus der Gruppe `docker`.<br/>• Führe nach den Änderungen unbedingt `sudo systemctl daemon-reload && sudo systemctl restart docker.socket && sudo systemctl restart docker.service` aus - das beweist, dass die Einstellungen einen Neustart des daemon überstehen und nicht nur vorübergehend dem erwarteten Zustand entsprechen.<br/>• Bestätige nach dem restart, dass Docker tatsächlich läuft (`sudo docker version`) und nicht nur gestoppt ist. |
| Abnahmekriterien | • **Docker läuft nach dem restart:** Nach `daemon-reload` + restart sind `docker.service` und `docker.socket` im Zustand `active`, und `sudo docker version`/`sudo docker info` enden erfolgreich (positive control - Docker läuft tatsächlich, ist nicht einfach "ausgeschaltet und deshalb ist 2375 zu").<br/>• **Keine TCP API:** Auf TCP/2375 gibt es keinen Listener. Nach dem restart hat die Docker API auf keinem Port einen TCP-Listener: effective `docker.service` enthält kein TCP `-H/--host`, und `docker.socket` enthält kein TCP `ListenStream`; der einzige API-Endpoint ist der Unix socket `/var/run/docker.sock`.<br/>• **Socket:** `stat -c '%U %G %a' /var/run/docker.sock` gibt `root root 660` zurück; das persistente override von `docker.service`/`docker.socket` (über `systemctl cat`) enthält kein `-H tcp://` und setzt `SocketGroup=root`/`SocketMode=0660`.<br/>• **Benutzer `developer`:** gehört nicht zur Gruppe `docker`, und `sudo -u developer docker ps` endet mit einem Zugriffsfehler.<br/>• **Artifacts:** Erstelle `/var/work/tests/artifacts/6/docker-tcp.txt`, `/var/work/tests/artifacts/6/docker-socket.txt`, `/var/work/tests/artifacts/6/developer-access.txt` mit den Zeilen `tcp/2375: closed`, `root root 660`, `developer docker ps: denied`. |

<details>
<summary>💡 Hinweis zu Aufgabe 6</summary>

Die Mitgliedschaft in der Gruppe `docker` ist faktisch gleichbedeutend mit root - jeder Prozess mit Zugriff auf `docker.sock` kann über einen `--privileged` container das Host-Dateisystem mounten. Um sicherzustellen, dass `developer` aus der Gruppe entfernt wurde, reicht `groups developer` nicht aus - Änderungen der Gruppenmitgliedschaft gelten für NEUE login-Sitzungen, prüfe gerade über `sudo -u developer docker ps` in einem frischen Befehl und nicht in einer bereits geöffneten Sitzung von `developer`. Höre nicht beim ersten erfolgreichen Lauf der Prüfung auf - führe `daemon-reload` und `restart` beider units (`docker.socket`, `docker.service`) aus und wiederhole die Prüfungen NOCHMAL: Ohne diesen Schritt kann man die Aufgabe versehentlich bestehen, indem man Docker einfach vorübergehend stoppt (dann ist 2375 nicht zu, weil `-H tcp://` entfernt wurde, sondern weil der daemon überhaupt nicht läuft) - stelle auch sicher, dass `sudo docker version` nach dem restart funktioniert, das beweist, dass Docker tatsächlich arbeitet und nicht nur "ausgeschaltet" ist.
</details>

---
| **7** | **Laden eines ungenutzten Kernelmoduls verbieten (`modprobe` blacklist)** |
| :---: | :--- |
| Was wir tun | • Auf der control-plane ist das Modul `sctp` geladen, wird aber in dieser Lab weder von kubeadm noch von containerd noch von Calico benötigt. Versuche, es zu entladen (`sudo modprobe -r sctp`).<br/>• **Das Entladen kann auf einem bereits laufenden Cluster scheitern, und das ist kein Fehler:** Protokoll-Kernelmodule erhalten für jedes zum Zeitpunkt ihres Ladens existierende netns eine persistente per-network-namespace-Referenz, und auf diesem Node laufen bereits Pods (calico, coredns usw.); sie zu stoppen gehört nicht zur Aufgabe.<br/>• Verbiete das erneute Laden über `/etc/modprobe.d/60-cks-sctp.conf` mit den Direktiven `blacklist sctp` und `install sctp /bin/true`.<br/>• Einschränkungen des Bedrohungsmodells: Beide Direktiven wirken auf Ebene von `modprobe` (alias resolution und dependency loading) - das ist kein absoluter Schutz des Kernels. `insmod` fügt das Modul direkt über einen Kernel-syscall ein und liest `modprobe.d` nicht, und `modprobe --ignore-install` kann das `install`-override bei entsprechendem Zugriff auf Host-Ebene umgehen. Für den root-Besitzer des Nodes ist das zu erwarten: Ziel ist es, den üblichen Ladepfad zu beseitigen (`modprobe sctp`, Autoload per alias beim Zugriff auf das Protokoll) und nicht, sich vor einem Benutzer zu schützen, der bereits root auf dem Node hat.<br/>• Bestätige, dass `modprobe --show-config` das effektive override zeigt und dass ein direktes `modprobe sctp` den Zustand des Moduls nicht ändert. |
| Abnahmekriterien | • **Datei:** `/etc/modprobe.d/60-cks-sctp.conf` enthält beide Zeilen `blacklist sctp` und `install sctp /bin/true`.<br/>• **Effektive Konfiguration:** `modprobe --show-config \| grep sctp` zeigt `install sctp /bin/true`.<br/>• **Zustand des Moduls:** Ein direktes erneutes `modprobe sctp` ändert den Zustand des Moduls nicht (war geladen - bleibt geladen, war nicht geladen - bleibt nicht geladen).<br/>• **Artifact:** `/var/work/tests/artifacts/7/sctp.txt` enthält die Zeile `lsmod: absent` ODER `lsmod: present` (eines der beiden - der reale aktuelle Zustand) und die Zeile `install sctp /bin/true`. |

<details>
<summary>💡 Hinweis zu Aufgabe 7</summary>

`blacklist sctp` allein blockiert nicht alles - es verhindert das AUTOLADEN per alias resolution, aber ein direktes `modprobe sctp` funktioniert ohne das `install`-override trotzdem. Beide Zeilen werden gebraucht: `blacklist` für das Autoload, `install sctp /bin/true` für den expliziten Aufruf `modprobe sctp` (ersetzt den Ladebefehl durch ein no-op). Versuche `sudo modprobe -r sctp`, um das bereits geladene Modul zu entladen, aber wenn du `FATAL: Module sctp is in use` mit leerem `/sys/module/sctp/holders` erhältst - ist das auf einem laufenden Cluster erwartet (per-netns pinning durch bereits gestartete Pods) und verhindert nicht das Bestehen der Aufgabe; die Konfiguration verhindert trotzdem ZUKÜNFTIGE Ladevorgänge, und genau das wird geprüft.
</details>

---
| **8** | **`protectKernelDefaults` und sichere sysctl für kubelet** |
| :---: | :--- |
| Was wir tun | • Auf der control-plane gilt derzeit `kernel.unprivileged_bpf_disabled = 0` - unprivilegierte Prozesse können eBPF-Programme laden, was die kernel attack surface erweitert. Korrigiere das.<br/>• Füge `vm.overcommit_memory = 1` hinzu (übliche Empfehlung für die Stabilität von kubelet/containerd unter memory pressure).<br/>• Setze beide Parameter über `/etc/sysctl.d/99-kubernetes.conf` und wende sie dann mit `sudo sysctl --system` an.<br/>• Aktiviere `protectKernelDefaults: true` in `/var/lib/kubelet/config.yaml` und starte kubelet neu.<br/>• **Die Reihenfolge ist wichtig:** Bei `true` prüft das kubelet beim Start, ob die aktuellen kernel/cgroup parameters den erwarteten defaults entsprechen, und **startet nicht**, wenn sie nicht übereinstimmen - daher müssen die sysctl **vor** dem Neustart des kubelet angewendet werden und nicht danach. |
| Abnahmekriterien | • **Live-Werte:** `sysctl kernel.unprivileged_bpf_disabled` gibt `1` zurück; `sysctl vm.overcommit_memory` gibt `1` zurück.<br/>• **Persistente Konfiguration:** `/etc/sysctl.d/99-kubernetes.conf` enthält beide Parameter als aktive Zeilen (`kernel.unprivileged_bpf_disabled = 1`, `vm.overcommit_memory = 1`); ein Kommentar, `= 1 # comment` oder ein temporäres `sysctl -w` zählen nicht.<br/>• **kubelet:** `/var/lib/kubelet/config.yaml` enthält `protectKernelDefaults: true`.<br/>• **Zustand nach dem Neustart:** `systemctl is-active kubelet` gibt `active` zurück, und der Node bleibt `Ready`. |

<details>
<summary>💡 Hinweis zu Aufgabe 8</summary>

Die Reihenfolge ist hier entscheidend und in der Beschreibung der Aufgabe absichtlich betont: zuerst `sysctl --system` (die Werte anwenden), ERST DANN `protectKernelDefaults: true` aktivieren und kubelet neu starten. Bei umgekehrter Reihenfolge entdeckt das kubelet beim Start eine Abweichung der kernel parameters von seinen Erwartungen und weigert sich zu starten - der Node bleibt NotReady, und du kannst die Ursache ohne Lesen der kubelet logs (`journalctl -u kubelet`) nicht verstehen. Die Prüfung orientiert sich an der TATSÄCHLICH GELTENDEN Konfiguration des kubelet über `kubectl get --raw="/api/v1/nodes/<node>/proxy/configz"` und nicht am Text von `config.yaml` - wenn die Zeile in der Datei auskommentiert ist oder einen Tippfehler enthält, könnte `grep` sie trotzdem finden, obwohl das kubelet weiter mit dem alten Standardwert arbeitet. Starte nach dem Bearbeiten der Datei unbedingt das kubelet neu und prüfe gerade über `configz`.
</details>

---
| **9** | **Überflüssige SUID-Binärdatei finden und entschärfen** |
| :---: | :--- |
| Was wir tun | • Führe auf der control-plane `find / -xdev -perm -4000 -type f 2>/dev/null` aus und finde unter den Ergebnissen `/usr/local/bin/cks-lab105-suid-tool` - eine Lern-Binärdatei, die extra mit SUID-Bit erstellt wurde und für keine Kubernetes-Komponente auf diesem Node benötigt wird.<br/>• Speichere die vollständige Liste der gefundenen SUID-Dateien **vor** der Korrektur in `/var/work/tests/artifacts/9/suid-before.txt`.<br/>• Entferne das SUID-Bit der Binärdatei (`chmod u-s`).<br/>• Speichere den Modus von `cks-lab105-suid-tool` **nach** der Korrektur in `/var/work/tests/artifacts/9/suid-after.txt`.<br/>• Fasse die System-SUID-Binärdateien (`passwd`, `sudo`, `mount` und ähnliche) nicht an: Ihr Entfernen bricht den regulären Betrieb des Betriebssystems und gehört nicht zum Umfang der Aufgabe. |
| Abnahmekriterien | • **Vor der Korrektur:** `suid-before.txt` enthält den Pfad `/usr/local/bin/cks-lab105-suid-tool` unter den gefundenen SUID-Dateien.<br/>• **Nach der Korrektur:** `stat -c '%a' /usr/local/bin/cks-lab105-suid-tool` gibt `755` zurück (ohne SUID-Bit `4`); `suid-after.txt` enthält `755`.<br/>• **System-Binärdateien:** Die regulären SUID-Binärdateien (zum Beispiel `/usr/bin/sudo` oder `/usr/bin/passwd`) behalten ihr SUID-Bit unangetastet. |

<details>
<summary>💡 Hinweis zu Aufgabe 9</summary>

`chmod u-s` entfernt gerade das SUID-Bit und lässt die übrigen Rechte unangetastet (anders als `chmod 755`, das auch alle anderen Rechtebits überschreibt - in diesem Fall stimmt das Ergebnis überein, aber `u-s` ist als allgemeine Gewohnheit sicherer). Führe `find / -perm -4000` nicht ohne `-xdev` aus, außer wenn unbedingt nötig - ohne es scannt der Befehl gemountete Netzwerk-/virtuelle Dateisysteme und kann sehr lange laufen oder hängen. Die Prüfung vergleicht den aktuellen Satz der System-SUID-Binärdateien mit der Baseline, die VOR Beginn der Lab festgehalten wurde - es ist verboten, irgendeine andere System-SUID-Binärdatei anzufassen (nicht nur `sudo`/`passwd`), und es hilft nicht, das SUID bei `sudo` einfach zurückzugeben, wenn du es versehentlich (oder absichtlich) bei etwas anderem entfernt hast. Pfade innerhalb von `/var/lib/containerd` (Schichten von container images über overlayfs) werden weder in der Baseline noch in der Prüfung berücksichtigt - das sind keine Dateien des Hosts, und ihr Satz ändert sich beim pull/extract von Images natürlicherweise unabhängig von dir.
</details>

---
| **10** | **Core dumps deaktivieren und SUID-Prozesse vor dem Speicherabbild schützen** |
| :---: | :--- |
| Was wir tun | • Ein core dump eines Prozesses kann entschlüsselte Secrets, private keys und tokens enthalten, die zum Zeitpunkt des crash im Speicher waren.<br/>• Füge auf der control-plane in `/etc/security/limits.conf` die Zeilen `* hard core 0` und `* soft core 0` ein (Begrenzung der Größe des core dump).<br/>• Verbiete den dump für SUID/privileged-Prozesse: `fs.suid_dumpable = 0` in `/etc/sysctl.d/99-kubernetes.conf` (dieselbe Datei wie in Aufgabe 8 - erstelle keine separate, konfligierende Datei).<br/>• **Unter Ubuntu reicht das nicht:** Der crash dump wird standardmäßig nicht direkt in eine Datei übergeben, sondern über `kernel.core_pattern`, das auf einen userspace pipe handler (Apport) zeigt. Apport fängt den crash in `/var/lib/apport/coredump/` unabhängig von `ulimit -c` ab, weil `RLIMIT_CORE` vom Kernel gerade für pipe-Handler ignoriert wird (siehe `man 5 core`: "RLIMIT_CORE will be ignored if the system is configured to pipe core dumps to a program").<br/>• Setze daher zusätzlich `kernel.core_pattern = |/bin/false` in derselben `/etc/sysctl.d/99-kubernetes.conf` - das ersetzt den pipe-handler durch einen garantiert nicht funktionierenden, und der Kernel erzeugt weder in eine Datei noch über Apport einen dump. Wende `sudo sysctl --system` an.<br/>• Bestätige: `sysctl fs.suid_dumpable` gibt `0` zurück, und `cat /proc/sys/kernel/core_pattern` gibt `\|/bin/false` zurück.<br/>• Bestätige: Eine neue login-shell (`bash -l` oder `sudo su - ubuntu -c 'ulimit -c'` - gerade mit `sudo`, ein gewöhnliches `su` auf sich selbst verlangt trotzdem ein Passwort) zeigt `ulimit -c` gleich `0`.<br/>• Bestätige: Nach einem echten crash eines Testprozesses (`SIGSEGV`) erscheint kein neuer core dump, weder in `/var/lib/apport/coredump/` noch anderswo. |
| Abnahmekriterien | • **Live-Werte:** `sysctl -n fs.suid_dumpable` gibt `0` zurück; `cat /proc/sys/kernel/core_pattern` gibt `\|/bin/false` zurück.<br/>• **Persistentes sysctl:** `/etc/sysctl.d/99-kubernetes.conf` enthält die aktiven (nicht auskommentierten) Zeilen `fs.suid_dumpable = 0` und `kernel.core_pattern = \|/bin/false`.<br/>• **Limits:** `/etc/security/limits.conf` enthält beide Zeilen `* hard core 0` und `* soft core 0`; eine neue login-shell zeigt `ulimit -c` gleich `0`.<br/>• **Crash probe:** Ein controlled crash eines Testprozesses erzeugt keinen neuen retained core dump.<br/>• **Artifact:** `/var/work/tests/artifacts/10/coredump.txt` enthält alle Bestätigungen, einschließlich des Ergebnisses des controlled crash probe. |

<details>
<summary>💡 Hinweis zu Aufgabe 10</summary>

`ulimit -c` in DEINER aktuellen SSH-Sitzung ändert sich nach dem Bearbeiten von `limits.conf` nicht - PAM-Limits werden nur beim Erstellen einer NEUEN Sitzung/login-shell angewendet. Prüfe über `sudo su - ubuntu -c 'ulimit -c'` (neuer login; `sudo` ist Pflicht - `su` fragt selbst auf sich selbst immer nach einem Passwort, wenn es nicht von root aufgerufen wird) oder öffne eine neue SSH-Sitzung, statt `ulimit -c` in derselben shell zu prüfen, in der du die Datei bearbeitet hast. Beide Werte werden gebraucht: `hard` ist die absolute Obergrenze, `soft` ist der standardmäßig geltende Wert; wenn nur `soft` gesetzt wird, kann der Prozess das Limit selbst bis zu `hard` anheben. Die zentrale Falle der Aufgabe: `ulimit -c 0` und `fs.suid_dumpable=0` **deaktivieren** core dumps unter Ubuntu von sich aus **nicht** - `man 5 core` sagt ausdrücklich, dass `RLIMIT_CORE` vom Kernel ignoriert wird, wenn `kernel.core_pattern` auf einen pipe-Handler (`|program`) zeigt, und Ubuntu leitet den crash standardmäßig gerade in einen solchen Handler (Apport), der den dump unabhängig von `ulimit` abfängt. Der einzige zuverlässige Weg ist, `kernel.core_pattern` selbst zu überschreiben (zum Beispiel auf `|/bin/false`) und nicht nur die Prozesslimits.
</details>

## Zusatz: kernel und containerd/CRI hardening

Das ist eine kurze node-local Übung über die Aufgaben 7–9 hinaus, die nicht zu den automatischen Kriterien der
fixture gehört. Sie zeigt einen breiteren CRI-Kontext, der nicht auf ein konkretes Kernelmodul beschränkt ist.

In dieser Lab verwendet Kubernetes **containerd** und nicht Docker. Daher müssen dieselben Prinzipien
auf das CRI angewendet werden: Prüfe die Rechte von `/run/containerd/containerd.sock` und
`/etc/containerd/config.toml`, füge keine gewöhnlichen Benutzer zu der Gruppe hinzu, die Zugriff auf
den Socket gibt, und erlaube `ctr`/`crictl` mit diesem Endpoint nur privilegierten
Administratoren. Ändere Eigentümer oder Modus des laufenden CRI-Sockets nicht blind: Eine fehlerhafte
Einstellung stoppt kubelet und workload.

```bash
ssh "$CP" "sudo stat -c '%U %G %a %n' /run/containerd/containerd.sock /etc/containerd/config.toml"
ssh "$CP" 'sudo -u nobody crictl --runtime-endpoint unix:///run/containerd/containerd.sock ps'
# erwartet wird eine Zugriffsverweigerung für den unprivilegierten Benutzer
```

## Prüfung

Starte auf `worker`:

```bash
check_result
```

Die Prüfung enthält `0 Init` und zehn unabhängige Tests. Sie prüft den Zustand beider
Hosts per SSH und die obligatorischen artifacts. Warte nach dem Ändern von `sshd_config` oder einer systemd unit
auf den Abschluss von `systemctl reload/restart`, bevor du die Prüfung erneut startest.

## Lösung

Referenzlösung: [worker/files/solutions/1_DE.MD](worker/files/solutions/1_DE.MD).

## Löschen

```bash
TASK=105 make delete_cks_task
```
