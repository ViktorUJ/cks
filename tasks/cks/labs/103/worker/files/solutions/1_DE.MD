[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 103 - Referenzlösung

> Die Befehle werden auf dem worker ausgeführt, sofern nicht ausdrücklich `control-plane` angegeben ist. Speichere vor dem Bearbeiten der
> static Pod manifests Kopien. Das Kubelet bemerkt die Änderung der Dateien selbst und erstellt die
> entsprechenden static Pods neu; lösche sie nicht über die Kubernetes API.
>
> In der Prüfung sind `k` (`alias k=kubectl`) und die bash-completion dafür auf dem SSH-Host bereits eingerichtet -
> verschwende keine Zeit mit deren Einrichtung, verwende einfach `k` (siehe Kapitel 33.6).

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
k config use-context "$CTX"
ssh control-plane hostname
```

## Aufgabe 1. kube-bench Bericht

`kube-bench` `0.16.0` ist auf der `control-plane` bereits installiert (wie in der echten Prüfung, wo
das CIS-Benchmark-Tooling auf den Nodes schon vorhanden ist) - er muss nicht vom worker dorthin kopiert werden. Kubernetes
`1.36` fehlt in der offiziellen support table von kube-bench noch; das eingebaute version mapping
dieser Version endet mit dem Eintrag `"1.34": "cis-1.12"` - neuere Profile (einschließlich
irgendeines Profils für 1.35/1.36) gibt es in `0.16.0` überhaupt nicht, daher verwenden wir genau `cis-1.12`
als das nächstliegende vorhandene. Wir starten kube-bench mit diesem Profil erzwungen als approximate
hardening signal und nicht als authoritative CIS compliance assessment.

```bash
mkdir -p /var/work/tests/artifacts/1
{
  printf 'kubernetes_version=%s\n' "$(k version -o json | jq -r '.serverVersion.gitVersion')"
  printf 'kube_bench_version=%s\n' "$(ssh control-plane 'sudo /opt/kube-bench/kube-bench version' | awk 'NF {print $NF}' | tail -1)"
  printf 'benchmark=cis-1.12\n'
  printf 'mapping_status=forced-approximate\n'
  ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --targets master,node,controlplane,etcd,policies'
} | tee /var/work/tests/artifacts/1/kube-bench.txt

grep '== Summary' /var/work/tests/artifacts/1/kube-bench.txt
# == Summary master ==
# == Summary node ==
# == Summary controlplane ==
# == Summary etcd ==
# == Summary policies ==
```

Vergewissere dich mit eigenen Augen, dass alle fünf `== Summary <target> ==` vorhanden sind - ohne explizites
`--targets` landet ein Teil davon (`etcd`, `policies`) nicht im Bericht.

## Aufgabe 2. Hardening kubelet

Rufe Feldnamen nicht aus dem Gedächtnis ab - in der Prüfung ist es schneller, sie direkt aus dem bereits erstellten
kube-bench-Bericht (Aufgabe 1) zu holen. Zu jedem check gibt es dort einen Abschnitt `== Remediations <target> ==`
mit fertigem Korrekturtext - `grep -A1` nach der Nummer des checks liefert sofort das benötigte Feld:

```bash
grep -A1 '^4.2.1 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.1 If using a Kubelet config file, edit the file to set `authentication: anonymous: enabled` to
# `false`.

grep '^4.2.4 ' /var/work/tests/artifacts/1/kube-bench.txt
# 4.2.4 If using a Kubelet config file, edit the file to set `readOnlyPort` to 0.
```

Auf der control-plane liest das kubelet `/var/lib/kubelet/config.yaml`. Im YAML müssen genau
die folgenden Felder stehen (füge gleichnamige Schlüssel nicht ein zweites Mal hinzu):

```yaml
readOnlyPort: 0
authentication:
  anonymous:
    enabled: false
```

Setze in der Prüfung nicht vor jeden Befehl `sudo` - werde einmal root (`sudo -i`), das ist
schneller:

```bash
ssh control-plane
sudo -i
cp /var/lib/kubelet/config.yaml ~/2-kubelet-config.yaml
vim /var/lib/kubelet/config.yaml
systemctl restart kubelet
systemctl is-active kubelet
exit   # aus der root-Shell
exit   # von der control-plane
```

Wir prüfen nicht den statischen Text der Datei, sondern die geltende Konfiguration, die das kubelet
tatsächlich angewendet hat - über die API `configz` (ein Text-Parsing von YAML lässt sich leicht durch ähnliche
Felder wie `webhook.enabled` täuschen, während `configz` widerspiegelt, was das kubelet selbst als seine
Konfiguration betrachtet):

```bash
NODE=$(k get nodes -l node-role.kubernetes.io/control-plane \
  -o jsonpath='{.items[0].metadata.name}')

k get --raw="/api/v1/nodes/${NODE}/proxy/configz" \
  | jq -e '
      (.kubeletconfig.readOnlyPort // 0) == 0 and
      .kubeletconfig.authentication.anonymous.enabled == false
    '

k wait --for=condition=Ready "node/${NODE}" --timeout=120s
```

## Aufgabe 3. Profiling beim kube-apiserver deaktivieren

Derselbe Ansatz wie in Aufgabe 2 - verwende den kube-bench-Bericht aus Aufgabe 1 als Quelle der
Wahrheit, rufe das Flag nicht aus dem Gedächtnis ab:

```bash
grep -A2 '^1.2.15 ' /var/work/tests/artifacts/1/kube-bench.txt
# 1.2.15 Edit the API server pod specification file /etc/kubernetes/manifests/kube-apiserver.yaml
# on the control plane node and set the below parameter.
# --profiling=false
```

Füge den Parameter in die `command`-Liste des Containers `kube-apiserver` ein.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/3-api.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Füge in das command-Array eine Zeile mit derselben Einrückung wie die übrigen Argumente ein:
# - --profiling=false
exit
exit

ssh control-plane "sudo grep -n -- '--profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml"
k get po -n kube-system -l component=kube-apiserver
# STATUS muss Running werden - wenn noch nicht, warte ein paar Sekunden und wiederhole
```

## Aufgabe 4. TLS Secret und Ingress

Erstelle eine minimale Anwendung und einen Service, erzeuge ein selbstsigniertes Zertifikat für
den exakten DNS-Namen, erstelle dann das TLS Secret und den Ingress. Der Controller `ingress-nginx` ist
in dieser Lab bereits installiert und Ready (lab-owned fixture, die Version ist im bootstrap festgelegt) - davon überzeugen wir uns,
bevor wir den Ingress erstellen.

Kurze Ressourcennamen (`ns` = namespace, `deploy` = deployment, `svc` = service,
`ing` = ingress, `po` = pod) sparen unter Zeitdruck Tipparbeit.

```bash
k get ingressclass
k -n ingress-nginx get deploy ingress-nginx-controller
k -n ingress-nginx get endpoints ingress-nginx-controller

k create ns cks-103
k -n cks-103 create deploy secure-app --image=viktoruj/ping_pong:alpine
k -n cks-103 set env deploy/secure-app SERVER_NAME=secure-app SRV_PORT=80
k -n cks-103 expose deploy secure-app --name=secure-app --port=80 --target-port=80
k -n cks-103 wait --for=condition=Available deploy/secure-app --timeout=60s

mkdir -p /tmp/cks-103-tls
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout /tmp/cks-103-tls/tls.key \
  -out /tmp/cks-103-tls/tls.crt \
  -subj '/CN=secure.cks.local' \
  -addext 'subjectAltName=DNS:secure.cks.local'

k -n cks-103 create secret tls secure-ingress-tls \
  --cert=/tmp/cks-103-tls/tls.crt --key=/tmp/cks-103-tls/tls.key

cat <<'EOF' | k apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: secure-ingress
  namespace: cks-103
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - secure.cks.local
    secretName: secure-ingress-tls
  rules:
  - host: secure.cks.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-app
            port:
              number: 80
EOF

k get secret,ing -n cks-103
k get ing secure-ingress -n cks-103 -o yaml
```

Bleibe nicht bei `k get ... -o yaml` stehen - wir bestätigen, dass der TLS Ingress tatsächlich
über den echten Controller funktioniert. `secure.cks.local` wird bereits zu einer echten Node-IP aufgelöst
(der bootstrap hat den Eintrag in `/etc/hosts` ergänzt), und `ingress-nginx-controller` ist ein Service vom Typ
`NodePort`, der auf jedem Node offen ist; daher wird curl direkt von dieser Maschine aus ausgeführt, ohne SSH
zum Cluster:

```bash
HTTPS_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
curl -k "https://secure.cks.local:${HTTPS_NODEPORT}/"
# HTTPCODE 200, der Body enthält "Server Name: secure-app"

HTTP_NODEPORT=$(k -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}')
curl -v "http://secure.cks.local:${HTTP_NODEPORT}/"
# < HTTP/1.1 308 Permanent Redirect
# < Location: https://secure.cks.local
```

Dieser HTTP→HTTPS-Redirect ist eine echte Prüfungsfrage und keine künstliche Anforderung
der Lab (siehe mock-Prüfung `tasks/cks/mock/04`, Aufgabe 4).

## Aufgabe 5. TLS hardening kube-apiserver und etcd

Suche den exakten Flag-Namen nicht in der Dokumentation - es ist schneller, die Binärdatei selbst aus einem bereits
laufenden Pod heraus zu fragen (`--help` gibt es bei jeder Komponente der control plane) und das Benötigte herauszugrepen:

```bash
k exec -n kube-system $(k get po -n kube-system -l component=kube-apiserver -o name) -- kube-apiserver --help | grep -i tls
# --tls-min-version string   Minimum TLS version supported. Possible values: VersionTLS10, VersionTLS11, VersionTLS12, VersionTLS13
# --tls-cipher-suites strings   Comma-separated list of cipher suites for the server. Preferred values: TLS_AES_128_GCM_SHA256, ...

k exec -n kube-system $(k get po -n kube-system -l component=etcd -o name) -- etcd --help | grep -i cipher
# --cipher-suites ''   Comma-separated list of supported TLS cipher suites between client/server and peers
```

Füge in beiden static Pod manifests die Parameter in den `command` ein. Beim kube-apiserver verlangt die Aufgabe
BEIDE Flags, obwohl den tatsächlichen Schutz bei `VersionTLS13` gerade `--tls-min-version` bietet
(Go wählt die TLS 1.3 cipher suites selbst, `--tls-cipher-suites` hat darauf keinen Einfluss - siehe Frage
2 im Abschnitt "Prüfe dich vor dem Start"). `--tls-cipher-suites` wird trotzdem explizit benötigt - das ist
defense-in-depth: Wenn die Mindestversion später auf 1.2 abgeschwächt wird, werden schwache Chiffrensätze
nicht von selbst aktiviert. Bei etcd (dort ist TLS 1.2 zulässig) schränkt `--cipher-suites` das Set
bereits jetzt tatsächlich ein und nicht erst für die Zukunft.

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-apiserver.yaml ~/5-api.yaml
cp /etc/kubernetes/manifests/etcd.yaml ~/5-etcd.yaml
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# Füge in command ein:
# - --tls-min-version=VersionTLS13
# - --tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
vim /etc/kubernetes/manifests/etcd.yaml
# Füge in command ein:
# - --cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
exit
exit

k get po -n kube-system -l component=etcd
# STATUS muss Running werden - wenn noch nicht, warte ein paar Sekunden und wiederhole
ssh control-plane "sudo grep -E -- '--tls-min-version=VersionTLS13|--tls-cipher-suites=' /etc/kubernetes/manifests/kube-apiserver.yaml"
ssh control-plane "sudo grep -- '--cipher-suites=' /etc/kubernetes/manifests/etcd.yaml"

mkdir -p /var/work/tests/artifacts/5
ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_3 -brief </dev/null' \
  > /var/work/tests/artifacts/5/tls13.txt 2>&1
# Protocol version: TLSv1.3 - die Verbindung kam zustande

ssh control-plane 'openssl s_client -connect 127.0.0.1:6443 -tls1_2 -brief </dev/null' \
  >> /var/work/tests/artifacts/5/tls13.txt 2>&1
# ssl3_read_bytes:tlsv1 alert protocol version - der handshake muss scheitern, genau das ist gewollt

echo 'TLS 1.2 correctly rejected (non-zero exit / handshake failure)' \
  >> /var/work/tests/artifacts/5/tls13.txt
cat /var/work/tests/artifacts/5/tls13.txt
```

Erwartet wird eine Zeile der Form `Protocol version: TLSv1.3` oder `Protocol : TLSv1.3`, und das Ende von
`openssl s_client -tls1_2` mit handshake-Fehler/non-zero exit muss als
`TLS 1.2 correctly rejected` festgehalten werden.

## Aufgabe 6. SHA-256 von kubelet und kubectl prüfen

Die Referenz wird nicht aus lokalen Dateien berechnet. Lade die offiziell veröffentlichten Summen von
Kubernetes `v1.36.0` herunter, bilde Dateien im Format `sha256sum -c` und speichere die Ergebnisse.

```bash
mkdir -p /var/work/tests/artifacts/6 /tmp/cks-103-sha
cd /tmp/cks-103-sha
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubectl.sha256
curl -fsSLO https://dl.k8s.io/release/v1.36.0/bin/linux/amd64/kubelet.sha256

printf '%s  %s\n' "$(cat kubectl.sha256)" "$(command -v kubectl)" > kubectl.check
scp kubelet.sha256 control-plane:/tmp/kubelet.sha256
ssh control-plane 'printf "%s  %s\\n" "$(cat /tmp/kubelet.sha256)" "$(command -v kubelet)" > /tmp/kubelet.check && sha256sum -c /tmp/kubelet.check' \
  | tee /var/work/tests/artifacts/6/binaries.sha256.txt
sha256sum -c kubectl.check | tee -a /var/work/tests/artifacts/6/binaries.sha256.txt

cat /var/work/tests/artifacts/6/binaries.sha256.txt
```

Beide Zeilen müssen mit `: OK` enden. Wenn der Pfad zur Binärdatei von `/usr/bin` abweicht,
bildet `command -v` trotzdem eine korrekte Eingabe für `sha256sum -c`.

## Aufgabe 7. Remediation cycle: von einem konkreten kube-bench FAIL bis PASS

Anders als in Aufgabe 1 (Snapshot des gesamten Berichts) musst du hier einen konkreten check
mit seiner Korrektur verbinden. `kube-bench` unterstützt den gezielten Lauf über `--check`, daher
muss der gesamte Bericht nicht manuell neu gelesen werden:

```bash
mkdir -p /var/work/tests/artifacts/7

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/before.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/before.txt
# [FAIL] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Prüfe das tatsächliche Zugriffsrecht auf dem Node und korrigiere es auf `600` - das ist eine file-only
Änderung, das kubelet erstellt den static Pod wegen einer Änderung der Rechte nicht neu, nur wegen einer Änderung des
Inhalts des Manifests:

```bash
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 644 /etc/kubernetes/manifests/kube-apiserver.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-apiserver.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-apiserver.yaml'
# 600 /etc/kubernetes/manifests/kube-apiserver.yaml
```

Der erneute gezielte Lauf desselben checks muss `PASS` zeigen:

```bash
ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.1' \
  | tee /var/work/tests/artifacts/7/after.txt
grep -A1 '1.1.1' /var/work/tests/artifacts/7/after.txt
# [PASS] 1.1.1 Ensure that the API server pod specification file permissions ...
```

Bestätige, dass der kube-apiserver gesund geblieben ist: Die Änderung der Dateirechte ändert den
Inhalt der Datei nicht, daher sollte das kubelet den static Pod nicht neu erstellen.

```bash
k get --raw='/readyz'
k -n kube-system get pods -l component=kube-apiserver
```

## Aufgabe 8. Remediation cycle: kube-controller-manager

Derselbe Ansatz wie in Aufgabe 7, für eine andere Komponente und eine andere check ID (`1.1.3` -
kube-controller-manager pod specification file permissions):

```bash
mkdir -p /var/work/tests/artifacts/8

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/before.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/before.txt
# [FAIL] 1.1.3 Ensure that the controller manager pod specification file permissions ...

ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 644 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo chmod 600 /etc/kubernetes/manifests/kube-controller-manager.yaml'
ssh control-plane 'sudo stat -c "%a %n" /etc/kubernetes/manifests/kube-controller-manager.yaml'
# 600 /etc/kubernetes/manifests/kube-controller-manager.yaml

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.1.3' \
  | tee /var/work/tests/artifacts/8/after.txt
grep -A1 '1.1.3' /var/work/tests/artifacts/8/after.txt
# [PASS] 1.1.3 Ensure that the controller manager pod specification file permissions ...

k -n kube-system get pods -l component=kube-controller-manager
```

## Aufgabe 9. Remediation cycle: profiling bei kube-controller-manager und kube-scheduler

Derselbe Ansatz wie in den Aufgaben 7-8 (ein konkretes `[FAIL]` über kube-bench finden, korrigieren,
`[PASS]` bestätigen), für die checks `1.3.2` (kube-controller-manager profiling) und `1.4.1`
(kube-scheduler profiling). Beide gehören, wie der gesamte Abschnitt `1.x`, im
`cis-1.12` zum target `master`, daher ist ein explizites `--targets` nicht nötig - genau wie in den Aufgaben 7-8. Aufgabe 3
hat profiling nur beim kube-apiserver deaktiviert; kubeadm fügt `--profiling=false` standardmäßig NICHT in die Manifeste
von kube-controller-manager/kube-scheduler ein.

```bash
mkdir -p /var/work/tests/artifacts/9

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-before.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-before.txt
# [FAIL] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-before.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-before.txt
# [FAIL] 1.4.1 Ensure that the --profiling argument is set to false ...
```

Wir korrigieren beide static Pod manifests - derselbe Ansatz wie in Aufgabe 3, nur für zwei
andere Komponenten:

```bash
ssh control-plane
sudo -i
cp /etc/kubernetes/manifests/kube-controller-manager.yaml ~/9-controller-manager.yaml
cp /etc/kubernetes/manifests/kube-scheduler.yaml ~/9-scheduler.yaml
vim /etc/kubernetes/manifests/kube-controller-manager.yaml
# Füge in das command-Array eine Zeile mit derselben Einrückung wie die übrigen Argumente ein:
# - --profiling=false
vim /etc/kubernetes/manifests/kube-scheduler.yaml
# - --profiling=false
exit
exit

k -n kube-system get pods -l component=kube-controller-manager
k -n kube-system get pods -l component=kube-scheduler
```

Wir prüfen nicht den Text der Datei, sondern den tatsächlich laufenden Pod (das kubelet erstellt den static Pod nach
einer Änderung des Manifests nicht augenblicklich neu), und der erneute gezielte Lauf desselben checks muss
`PASS` zeigen:

```bash
k -n kube-system get pod -l component=kube-controller-manager -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

k -n kube-system get pod -l component=kube-scheduler -o json \
  | jq -e '.items[0].spec.containers[0].command | index("--profiling=false") != null'

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.3.2' \
  | tee /var/work/tests/artifacts/9/controller-manager-after.txt
grep -A1 '1.3.2' /var/work/tests/artifacts/9/controller-manager-after.txt
# [PASS] 1.3.2 Ensure that the --profiling argument is set to false ...

ssh control-plane 'sudo /opt/kube-bench/kube-bench run --benchmark cis-1.12 --check 1.4.1' \
  | tee /var/work/tests/artifacts/9/scheduler-after.txt
grep -A1 '1.4.1' /var/work/tests/artifacts/9/scheduler-after.txt
# [PASS] 1.4.1 Ensure that the --profiling argument is set to false ...
```

`jq -e` muss für beide Komponenten `true` ausgeben, und beide Befehle `k get pods`
oben müssen `Running` zeigen.

## Aufgabe 10. Remediation cycle: protect-kernel-defaults auf dem worker-Node

Derselbe Ansatz wie in den Aufgaben 7-9, jetzt auf dem ECHTEN worker-Node (nicht der control-plane), aber für ein
ANDERES Profil. Das festgelegte `kube-bench 0.16.0`/`cis-1.12` (in allen übrigen
Aufgaben dieser Lab verwendet) enthält den check protect-kernel-defaults überhaupt nicht - CIS hat ihn ab dieser Version des Profils entfernt/
umnummeriert; das eigene `4.2.6` in `cis-1.12` ist ein
ANDERER check (`--make-iptables-util-chains`, standardmäßig `PASS`, hat mit protect-kernel-defaults
nichts zu tun). Der benötigte check mit derselben ID `4.2.6` existiert im älteren Profil
`cis-1.24` derselben Binärdatei - verwende genau dieses Profil, mit explizitem `--benchmark cis-1.24`, nur
für diese eine Aufgabe.

Anders als auf der control-plane ist `kube-bench` auf dem worker-Node NICHT vorinstalliert - installiere ihn
hier selbst (echte Installation, keine Kopie von der control-plane oder dem worker PC): Lade dasselbe
festgelegte Release von GitHub herunter, entpacke `binary` und `cfg` in das default `--config-dir`
(`/etc/kube-bench/cfg`), um dieses Flag nicht in jedem Befehl explizit angeben zu müssen:

```bash
WORKER_NODE=$(k get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}')

cat <<'EOF' > /tmp/install-kube-bench.sh
KUBE_BENCH_VERSION=0.16.0
arch=$(dpkg --print-architecture)
workdir=$(mktemp -d)
asset="kube-bench_${KUBE_BENCH_VERSION}_linux_${arch}.tar.gz"
base="https://github.com/aquasecurity/kube-bench/releases/download/v${KUBE_BENCH_VERSION}"
curl -fsSL -o "$workdir/$asset" "$base/$asset"
# Derselbe Ansatz wie in Aufgabe 6: Abgleich mit einer unabhängig veröffentlichten Summe und nicht mit
# einer aus der Datei selbst berechneten Summe.
curl -fsSL -o "$workdir/checksums.txt" "$base/kube-bench_${KUBE_BENCH_VERSION}_checksums.txt"
(cd "$workdir" && grep -E "[[:space:]]${asset}\$" checksums.txt | sha256sum --check --strict -)
tar -xzf "$workdir/$asset" -C "$workdir"
sudo install -d -m 0755 /opt/kube-bench /etc/kube-bench
sudo cp -a "$workdir"/cfg /etc/kube-bench/cfg
sudo install -m 0755 "$workdir/kube-bench" /opt/kube-bench/kube-bench
sudo ln -sf /opt/kube-bench/kube-bench /usr/local/bin/kube-bench
rm -rf "$workdir"
EOF
scp /tmp/install-kube-bench.sh "$WORKER_NODE":/tmp/install-kube-bench.sh
ssh "$WORKER_NODE" 'bash /tmp/install-kube-bench.sh'
ssh "$WORKER_NODE" 'kube-bench version'

mkdir -p /var/work/tests/artifacts/10
ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/before.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/before.txt
# [FAIL] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```

`protectKernelDefaults` ist in der von kubeadm erzeugten `KubeletConfiguration` überhaupt nicht enthalten -
das Feld fehlt physisch (gleichbedeutend mit dem unsicheren Default `false`), daher
füge es einfach hinzu und suche keine vorhandene Zeile zum Ersetzen:

```bash
ssh "$WORKER_NODE" 'echo "protectKernelDefaults: true" | sudo tee -a /var/lib/kubelet/config.yaml'
ssh "$WORKER_NODE" 'sudo systemctl restart kubelet'
k get node "$WORKER_NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}{"\n"}'
```

Bestätige über `/configz` (tatsächlich angewendete Konfiguration, nicht der Text der Datei) und
durch einen erneuten gezielten Lauf des checks:

```bash
k get --raw="/api/v1/nodes/$WORKER_NODE/proxy/configz" \
  | jq -e '.kubeletconfig.protectKernelDefaults == true'

ssh "$WORKER_NODE" 'sudo kube-bench run --benchmark cis-1.24 --check 4.2.6' \
  | tee /var/work/tests/artifacts/10/after.txt
grep -A1 '4.2.6' /var/work/tests/artifacts/10/after.txt
# [PASS] 4.2.6 Ensure that the --protect-kernel-defaults argument is set to true ...
```
