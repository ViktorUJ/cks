[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 112 - Referenzlösung: Falco, audit-Logs und Unveränderlichkeit

Wir arbeiten wie in der Prüfung. Öffne **zwei Terminals** und lass beide bis zum Ende der Lab offen:

- **Terminal 1 - control-plane:** `ssh control-plane`, dann `sudo -i` (danach werden alle Befehle auf dem Node
  als root ausgeführt, ohne `sudo`). Der einzige Node der control plane führt auch die workloads aus.
- **Terminal 2 - Arbeitsmaschine:** hier `kubectl`, `scp` und Prüfungen.

Artefakte, die auf dem Node gewonnen wurden, werden in `/tmp/art/<Nummer der Aufgabe>/` auf der control-plane gespeichert und
per `scp` auf die Arbeitsmaschine nach `/var/work/tests/artifacts/<Nummer>/` kopiert.

## Wo du Beispiele in der Dokumentation findest

| Was du brauchst | Seite und Abschnitt |
| :--- | :--- |
| Installation von Falco über apt (Schlüssel, Repository, `apt-get install -y falco`), Variablen `FALCO_DRIVER_CHOICE` / `FALCO_FRONTEND`, `systemctl enable falco-modern-bpf.service` | [Falco - Install: apt (Debian/Ubuntu), Environment variables, Systemd setup](https://falco.org/docs/setup/packages/#install-with-apt) |
| Überschreiben von Falco-Regeln und -Macros (`override: condition/output: replace/append`) | [Falco - Overriding rules: Examples of using the override section](https://falco.org/docs/concepts/rules/overriding/#examples-of-using-the-override-section) |
| Audit Policy (Stufen `None`/`Metadata`/`Request`/`RequestResponse`, `omitStages`, `rules`), Flags `--audit-policy-file`, `--audit-log-path`, `--audit-log-maxage/-maxbackup/-maxsize`, `hostPath`-Mount, webhook backend | [Kubernetes - Auditing: Audit policy, Log backend, Webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#audit-policy) |
| `readOnlyRootFilesystem` und `emptyDir` | [Kubernetes - Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) |
| Deny-all `NetworkPolicy` | [Kubernetes - Network Policies: Default deny all ingress and all egress traffic](https://kubernetes.io/docs/concepts/services-networking/network-policies/#default-deny-all-ingress-and-all-egress-traffic) |
| Kyverno `ValidatingPolicy` | [Kyverno - Validating Policies](https://kyverno.io/docs/policy-types/validating-policy/) |

Erster Start auf der Arbeitsmaschine (Terminal 2):

```bash
kubectl config use-context cluster1-admin@cluster1
export NS=runtime-112
mkdir -p /var/work/tests/artifacts/{2,3,4,5,6,9,10}
```

Erster Start auf dem Node (Terminal 1):

```bash
ssh control-plane
sudo -i
mkdir -p /tmp/art/{2,3,4,6,9,10}
```

## 1. Falco mit modern eBPF installieren

Wir installieren Falco aus dem offiziellen APT-Repository (Befehle von der Seite Install in der Dokumentation
von Falco). Modern eBPF erfordert kein manuelles Bauen oder Laden eines kernel module.

```bash
# Terminal 1 (control-plane, root)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" >> /etc/apt/sources.list.d/falcosecurity.list
apt-get update -y
```

**Führe die Installation als separaten Befehl aus:** `apt-get` leert den Eingabepuffer des Terminals, daher
gehen Zeilen, die direkt danach eingefügt werden, verloren.

```bash
# Terminal 1 (control-plane, root)
FALCO_FRONTEND=noninteractive FALCOCTL_ENABLED='' FALCO_DRIVER_CHOICE=modern_ebpf apt-get install -y falco
```

```bash
# Terminal 1 (control-plane, root)
mkdir -p /etc/falco/config.d
cat > /etc/falco/config.d/engine-kind.yaml <<EOF
engine:
  kind: modern_ebpf
EOF
# Das Paket installiert die unit falco-modern-bpf.service, und falco.service ist nur ein alias darauf;
# `systemctl enable falco` über den alias endet mit einem Fehler, daher aktivieren wir die echte unit.
systemctl enable --now falco-modern-bpf
falco --version; systemctl is-active falco; grep -R modern_ebpf /etc/falco
sleep 20
```

`sleep 20` ist nötig, weil sich beim ersten Start die modern eBPF probe mit mehreren
Wiederholungsversuchen öffnet (im journal sind mehrere Zeilen `Opening 'syscall' source` zu sehen): Solange sie nicht
geöffnet ist, erfasst Falco keine Ereignisse, und die shell aus Aufgabe 2 kann unbemerkt bleiben. Wenn
kein alert erscheint, wiederhole das `exec` nach einigen Sekunden.

Wenn der Dienst nicht startet, sieh dir zuerst `journalctl -u falco-modern-bpf -b --no-pager` an.
Ersetze die engine nicht durch ein kernel module: In dieser Lab wird genau `modern_ebpf` verlangt.

## 2. Standardregel für eine shell im Container

```bash
# Terminal 2 (Arbeitsmaschine)
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: falco-shell
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/falco-shell --timeout=120s
kubectl exec -it -n "$NS" falco-shell -- /bin/sh
# In der shell: exit
```

Speichere das echte Falco-Ereignis: Es stammt aus dem journal auf der control-plane. Falco schreibt das Ereignis mit
einer kleinen Verzögerung, warte daher nach dem Verlassen der shell ein paar Sekunden. Erstelle das Artefakt nicht
von Hand:

```bash
# Terminal 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'A shell was spawned in a container with an attached terminal' | tail -1 > /tmp/art/2/falco-shell.log
cat /tmp/art/2/falco-shell.log
```

```bash
# Terminal 2
scp control-plane:/tmp/art/2/falco-shell.log /var/work/tests/artifacts/2/
```

## 3. Lokale Regel und kontrollierter marker

Falco lädt `/etc/falco/falco_rules.local.yaml` bereits; wir fügen die Regel genau dort hinzu.
`spawned_process` erhält die Kompatibilität mit den Falco-Regeln, und `container` erlaubt es nicht,
denselben marker zu matchen, der auf dem Host gestartet wurde.

```bash
# Terminal 1 (control-plane, root)
cat > /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Custom Shell Marker
  desc: Detect the controlled CKS lab marker in a container process command line
  condition: spawned_process and container and proc.cmdline contains "CKS112_CUSTOM_EVENT"
  output: "CKS112 custom shell marker container=%container.id pid=%proc.pid ppid=%proc.ppid user=%user.name command=%proc.cmdline"
  priority: WARNING
EOF
systemctl restart falco && systemctl is-active falco && sleep 10
```

```bash
# Terminal 2
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT >/dev/null'
```

```bash
# Terminal 1
sleep 2
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 custom shell marker' | tail -1 > /tmp/art/3/falco-custom.log
cat /tmp/art/3/falco-custom.log
```

```bash
# Terminal 2
scp control-plane:/tmp/art/3/falco-custom.log /var/work/tests/artifacts/3/
```

Nach jedem `restart falco` steht in der Lösung `sleep 10`: Falco lädt die Regeln und die Metadaten der
Container etwa 5 Sekunden lang, und Ereignisse, die früher stattgefunden haben, schreibt er nicht ins journal.

## 4. Audit: RequestResponse für ConfigMap, Metadata für Secret

Wir erstellen die policy nach der Regel aus Kapitel 32: Vollständiges request/response schreiben wir nur für die
nicht sensiblen `configmaps` in `runtime-112`; für `secrets` nehmen wir `Metadata`, damit der Body des Secrets
(Tokens, Passwörter) nicht ins Log gelangt. `None` und `omitStages` reduzieren tatsächlich das high-volume
noise; das abschließende catch-all `Metadata` ist fallback logging und keine Rauschunterdrückung. Die Reihenfolge der Regeln ist wichtig:
spezifische Regeln stehen vor dem catch-all. Die Struktur der Datei stammt aus dem Beispiel in der Dokumentation (Abschnitt Audit
policy).

```bash
# Terminal 1 (control-plane, root)
cat > /etc/kubernetes/audit/policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
omitStages: ["RequestReceived"]
rules:
# 1. Noise reduction: high-volume events and health probes are not forensic evidence here.
- level: None
  resources:
  - group: ""
    resources: ["events"]
- level: None
  nonResourceURLs: ["/healthz*", "/livez*", "/readyz*", "/version"]
# 2. ConfigMap: constrained forensic RequestResponse example.
- level: RequestResponse
  namespaces: ["runtime-112"]
  resources:
  - group: ""
    resources: ["configmaps"]
# 3. Secret matters for investigation, but its body must not be logged.
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
# 4. Fallback logging for the rest of the API (not noise reduction).
- level: Metadata
EOF
```

Bearbeite `/etc/kubernetes/manifests/kube-apiserver.yaml` auf der control-plane (`vim`). Füge in `command`
des Containers `kube-apiserver` hinzu:

```yaml
- --audit-policy-file=/etc/kubernetes/audit/policy.yaml
- --audit-log-path=/var/log/kubernetes/audit/audit.log
- --audit-log-maxage=7
- --audit-log-maxbackup=3
- --audit-log-maxsize=100
```

Füge in `volumeMounts` desselben Containers hinzu:

```yaml
- name: audit-policy
  mountPath: /etc/kubernetes/audit
  readOnly: true
- name: audit-log
  mountPath: /var/log/kubernetes/audit
```

Füge in `spec.volumes` hinzu:

```yaml
- name: audit-policy
  hostPath:
    path: /etc/kubernetes/audit
    type: Directory
- name: audit-log
  hostPath:
    path: /var/log/kubernetes/audit
    type: DirectoryOrCreate
```

```bash
# Terminal 1 (control-plane, root)
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Das ist ein static Pod: Das kubelet erstellt den API server automatisch neu (etwa eine Minute, bis dahin
antwortet `kubectl` mit `connection refused`). Warte, bis er bereit ist:

```bash
# Terminal 2: wiederhole, bis der Befehl "ok" zurückgibt
kubectl get --raw=/readyz
```

```bash
# Terminal 1: die Flags sind im aktiven manifest gelandet
grep -E -- '--audit-(policy-file|log-path|log-max)' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Erstelle die ConfigMap und erzeuge beide Anfragen, speichere dann je ein passendes JSON event
als Artefakte:

```bash
# Terminal 2
kubectl create configmap audit-config -n "$NS" --from-literal=note=cks112 --dry-run=client -o yaml | kubectl apply -f -
kubectl get configmap audit-config -n "$NS" -o json >/dev/null
kubectl get secret audit-secret -n "$NS" -o json >/dev/null
```

```bash
# Terminal 1 (control-plane, root)
# ConfigMap: vollständiges RequestResponse event (nicht sensible Daten).
jq -c 'select(.level == "RequestResponse" and .objectRef.resource == "configmaps" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-config")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/configmap-request-response.json

# Secret: nur Metadata, ohne Body.
jq -c 'select(.objectRef.resource == "secrets" and .objectRef.namespace == "runtime-112" and .objectRef.name == "audit-secret")' /var/log/kubernetes/audit/audit.log | tail -1 > /tmp/art/4/secret-metadata.json
```

```bash
# Terminal 2
scp control-plane:/tmp/art/4/*.json /var/work/tests/artifacts/4/
```

Prüfe, dass die ConfigMap mit Body protokolliert ist und das Secret nur auf der Stufe `Metadata` und
**ohne** `requestObject`/`responseObject`:

```bash
# Terminal 2
jq '{level, verb, objectRef, hasBody: (has("requestObject") or has("responseObject"))}' \
  /var/work/tests/artifacts/4/configmap-request-response.json
jq '{level, verb, objectRef, hasRequestObject: has("requestObject"), hasResponseObject: has("responseObject")}' \
  /var/work/tests/artifacts/4/secret-metadata.json
```

## 5. Unveränderliches root filesystem

`emptyDir` gibt der Anwendung einen kontrollierten Ort für runtime-Dateien; das root filesystem
bleibt read-only. `hostPath` wird nicht gebraucht und ist nicht zulässig.

```bash
# Terminal 2
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: immutable-app
  namespace: runtime-112
spec:
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
    securityContext:
      readOnlyRootFilesystem: true
    volumeMounts:
    - name: writable-tmp
      mountPath: /tmp
  volumes:
  - name: writable-tmp
    emptyDir: {}
EOF
kubectl wait -n "$NS" --for=condition=Ready pod/immutable-app --timeout=120s
```

Wir belegen beide Eigenschaften und speichern die Ablehnungsmeldung:

```bash
# Terminal 2
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /cks-112-write-denied' > /var/work/tests/artifacts/5/rootfs-write-denied.log 2>&1
cat /var/work/tests/artifacts/5/rootfs-write-denied.log
# touch: /cks-112-write-denied: Read-only file system
kubectl exec -n "$NS" immutable-app -- sh -c 'touch /tmp/allowed && test -f /tmp/allowed'
```

## 6. Minimale containment-Kette vom Alert bis zur Isolation

Das audit backend läuft bereits, daher hinterlässt ein neues `kubectl exec` API evidence. Wir starten
einen kontrollierten langlebigen Prozess: Der marker bleibt in der command line lange genug für
die Prüfung von `/proc`. In production startet man einen verdächtigen Prozess nicht erneut; hier ist das
safe planted evidence einer einmaligen Lab.

```bash
# Terminal 1 (control-plane, root): Startzeitpunkt des Durchlaufs (die Zeit nehmen wir von der control-plane,
# wo wir später das journal lesen)
START=$(date '+%Y-%m-%d %H:%M:%S')
```

```bash
# Terminal 2
DIR=/var/work/tests/artifacts/6
kubectl exec -n "$NS" falco-shell -- \
  sh -c 'sleep 600; echo completed' CKS112_CUSTOM_EVENT >/tmp/cks112-incident-exec.log 2>&1 &
INCIDENT_EXEC_PID=$!
```

Alles Weitere machen wir auf der control-plane, solange der Prozess lebt: Wir nehmen den alert und aus ihm die container id und
die host pid (wir beginnen mit dem alert und raten nicht):

```bash
# Terminal 1 (control-plane, root)
cd /tmp/art/6
journalctl -u falco-modern-bpf -b --since "$START" --no-pager | grep -F 'CKS112 custom shell marker' | tail -1 > falco-alert.log
cat falco-alert.log

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' falco-alert.log | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' falco-alert.log | tail -1)
echo "SHORT_ID=$SHORT_ID HOST_PID=$HOST_PID"

CONTAINER_ID=$(crictl ps -a -q | grep "^$SHORT_ID" | head -1)
crictl inspect $CONTAINER_ID > cri-container.json
SANDBOX_ID=$(jq -r '.status.sandboxId // .status.sandboxID // .info.sandboxID // empty' cri-container.json)
crictl inspectp $SANDBOX_ID > cri-sandbox.json
printf 'container_init_pid=%s\n' "$(jq -r '.info.pid // empty' cri-container.json)" > cri-mapping.txt

cat /proc/$HOST_PID/status > proc-status.txt
tr '\0' ' ' < /proc/$HOST_PID/cmdline > proc-cmdline.txt; echo >> proc-cmdline.txt
cat /proc/$HOST_PID/cgroup > proc-cgroup.txt
ps -eo pid,ppid,user,lstart,args --forest > process-tree.txt
```

Jetzt korrelieren wir das API event. Das moderne `kubectl exec` arbeitet über WebSocket, daher ist es im audit
als `get` zu sehen (bei SPDY-fallback - `create`), beide Varianten sind passend. Für `pods/exec` genügt
`Metadata`: Das command aus dem request body kann geheime Daten enthalten, daher wird `RequestResponse` hier nicht gebraucht.

```bash
# Terminal 1 (control-plane, root)
jq -c 'select(.level == "Metadata" and (.verb == "create" or .verb == "get") and .objectRef.resource == "pods" and .objectRef.subresource == "exec" and .objectRef.namespace == "runtime-112" and .objectRef.name == "falco-shell")' /var/log/kubernetes/audit/audit.log | tail -1 > audit-exec.json
jq '{verb, level, hasRequestObject: has("requestObject")}' audit-exec.json
```

```bash
# Terminal 2: alle Dateien der Kette abholen und die abschließende summary zusammenstellen
scp 'control-plane:/tmp/art/6/*' /var/work/tests/artifacts/6/

SHORT_ID=$(sed -n 's/.*container=\([^ ]*\).*/\1/p' "$DIR/falco-alert.log" | tail -1)
HOST_PID=$(sed -n 's/.* pid=\([0-9][0-9]*\) .*/\1/p' "$DIR/falco-alert.log" | tail -1)
CONTAINER_ID=$(jq -r '.status.id' "$DIR/cri-container.json")
POD=$(jq -r '.status.metadata.name' "$DIR/cri-sandbox.json")
NAMESPACE=$(jq -r '.status.metadata.namespace' "$DIR/cri-sandbox.json")
NODE=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.spec.nodeName}')
CONTAINER_INIT_PID=$(jq -r '.info.pid // empty' "$DIR/cri-container.json")

cat > "$DIR/evidence-summary.txt" <<EOF
alert_rule=CKS112 Custom Shell Marker
namespace=$NAMESPACE
pod=$POD
node=$NODE
runtime=containerd
container_id=$CONTAINER_ID
container_init_pid=$CONTAINER_INIT_PID
host_pid=$HOST_PID
audit_verb=$(jq -r .verb "$DIR/audit-exec.json")
audit_subresource=exec
attack_phase=Execution
technique=Container Administration Command
containment=quarantine-and-delete
EOF
cat "$DIR/evidence-summary.txt"
```

Zuerst speichern wir die evidence, dann isolieren wir den Namespace auf Netzwerkebene und löschen den
kompromittierten Pod. Das ist die minimale containment-Kette und keine vollständige Untersuchung:
credential revocation/rotation, die Suche nach anderen workloads und die Wiederherstellung von owner/controller erfolgen
in einem separaten IR-Prozess. Der letzte Befehl belegt das negative outcome und sucht nicht nach einem konkreten
Text der Fehlermeldung.

```bash
# Terminal 2
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: incident-quarantine
  namespace: runtime-112
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress: []
  egress: []
EOF

kubectl delete pod falco-shell -n "$NS" --wait=true
wait "$INCIDENT_EXEC_PID" 2>/dev/null
kubectl exec -n "$NS" falco-shell -- sh -c 'echo CKS112_CUSTOM_EVENT' > "$DIR/post-containment-exec.log" 2>&1
printf 'pod=deleted\nnetworkpolicy=incident-quarantine\nexec_exit=%s\n' "$?" > "$DIR/containment.txt"
cat "$DIR/containment.txt"
# exec_exit=1 (nicht 0)
```

## 7. Override des upstream-Macros und Ausgabe in JSON/Datei

Die Standardregel **Terminal shell in container** löst auch bei einem legitimen
Werkzeug aus. Der richtige Ort für eine environment-specific Ausnahme ist nicht das Bearbeiten
der Regel selbst, sondern das override des reservierten upstream-Macros gerade dieser Regel:
`user_expected_terminal_shell_in_container_conditions` (standardmäßig `(never_true)`, das
heißt, es gibt keine Ausnahmen). Verwechsle es nicht mit dem im Namen ähnlichen `user_shell_container_exclusions` -
dieses gehört zu einer separaten Regel **Run shell untrusted** ("Shell spawned by untrusted
binary") und beeinflusst **Terminal shell in container** nicht. Verwende `k8s.pod.name` und
`k8s.ns.name` und nicht `container.name`: `container.name` ist der Name des **Containers** (hier
`app`) und nicht des Pods, und eine Übereinstimmung nach dem Namen des Containers ergibt fast immer eine falsche oder zu
breite allowlist.

```bash
# Terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- macro: user_expected_terminal_shell_in_container_conditions
  condition: (k8s.ns.name = "runtime-112" and k8s.pod.name = "ci-runner")
  override:
    condition: replace
EOF
systemctl restart falco && sleep 10
```

Erstelle einen Pod mit interaktiver shell unter dem Namen, der jetzt ausgenommen ist:

```bash
# Terminal 2
kubectl apply -n runtime-112 -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ci-runner
  labels:
    app: ci-runner
spec:
  containers:
  - name: app
    image: busybox:1.36
    command: ["sleep", "3600"]
    stdin: true
    tty: true
EOF
kubectl wait -n runtime-112 --for=condition=Ready pod/ci-runner --timeout=60s
kubectl exec -n runtime-112 -it ci-runner -- sh -c 'echo shell-open; sleep 2'
```

Prüfe separat, dass `immutable-app` aus Aufgabe 5 (ohne Ausnahme) weiterhin einen alert erzeugt - das override
darf die Regel nicht still als Ganzes ausschalten:

```bash
# Terminal 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# Terminal 1
journalctl -u falco-modern-bpf -b --no-pager -n 200 | grep -F 'A shell was spawned in a container with an attached terminal'
```

Der Standard-output der Regel **Terminal shell in container** enthält nicht `k8s.pod.name`/
`k8s.ns.name` (das kannst du auf der control-plane selbst prüfen: `grep -A3 "rule: Terminal shell in container" /etc/falco/falco_rules.yaml`
zeigt `output` ohne diese Felder). Ohne Pod/namespace evidence im alert selbst ist eine zuverlässige correlation
einer konkreten Auslösung mit einem konkreten Pod unmöglich - ein Text-`grep` nach dem Pod-Namen im journal
findet einfach keine Übereinstimmung. Wir fügen diese Felder über denselben `override`-Mechanismus hinzu, aber mit
`output: append` statt `condition: replace`:

```bash
# Terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: Terminal shell in container
  output: ' k8s_ns=%k8s.ns.name k8s_pod=%k8s.pod.name'
  override:
    output: append
EOF
systemctl restart falco && sleep 10
```

Aktiviere in `/etc/falco/config.d/` das JSON-Format und die Dateiausgabe. Falco 0.38+ übernimmt standardmäßig
`config_files` aus diesem Verzeichnis; das Anhängen direkt an `falco.yaml` erzeugt
doppelte top-level-Schlüssel beim erneuten Start und übersteht ein Paket-Update schlechter -
`config.d` ist gerade für lokale Ergänzungen vorgesehen:

```bash
# Terminal 1 (control-plane, root)
mkdir -p /var/log/falco /etc/falco/config.d
cat > /etc/falco/config.d/cks112-output.yaml <<EOF
json_output: true
file_output:
  enabled: true
  filename: /var/log/falco/events.log
EOF
systemctl restart falco && sleep 10
```

Wir bestätigen strukturiert über `output_fields` und nicht per Text-`grep` nach dem Pod-Namen -
das funktioniert zuverlässig unabhängig davon, wie genau die Zeile `output` formatiert ist:

```bash
# Terminal 2
kubectl exec -n runtime-112 -it immutable-app -- sh -c 'echo shell-open; sleep 2'
```

```bash
# Terminal 1 (control-plane, root)
sleep 2
tail -n 20 /var/log/falco/events.log \
  | jq -c 'select(.rule == "Terminal shell in container" and .output_fields["k8s.pod.name"] == "immutable-app" and .output_fields["k8s.ns.name"] == "runtime-112")' \
  | tail -1 \
  | jq '{pod: .output_fields["k8s.pod.name"], ns: .output_fields["k8s.ns.name"]}'
# {"pod": "immutable-app", "ns": "runtime-112"}
```

## 8. Audit webhook backend

`audit-receiver` ist vom Startskript bereits bereitgestellt. Erstelle eine webhook kubeconfig, die auf
seinen Service zeigt; für die Lab ist HTTP zulässig, in production erfordert der webhook HTTPS und ein client
certificate (Kapitel 32).

```bash
# Terminal 2: ClusterIP Service audit-receiver
kubectl get svc audit-receiver -n runtime-112 -o jsonpath='{.spec.clusterIP}'; echo
```

```bash
# Terminal 1 (control-plane, root)
RECEIVER_IP=10.111.15.20     # trage die ClusterIP ein, die Terminal 2 ausgegeben hat
cat > /etc/kubernetes/audit/webhook-config.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
- name: audit-receiver
  cluster:
    server: http://${RECEIVER_IP}:8080/audit
users:
- name: kube-apiserver-audit
  user: {}
contexts:
- name: audit-webhook
  context:
    cluster: audit-receiver
    user: kube-apiserver-audit
current-context: audit-webhook
EOF
```

Ergänze die webhook-Flags im static manifest und **behalte** dabei die bereits konfigurierten Flags des file backend
aus Aufgabe 4 - der webhook ergänzt den lokalen Log und ersetzt ihn nicht:

```bash
# Terminal 1 (control-plane, root)
mkdir -m 700 /etc/kubernetes/backup
cp -p /etc/kubernetes/manifests/kube-apiserver.yaml /etc/kubernetes/backup/kube-apiserver.yaml.pre-webhook
vim /etc/kubernetes/manifests/kube-apiserver.yaml
# In command hinzufügen:
#   - --audit-webhook-config-file=/etc/kubernetes/audit/webhook-config.yaml
#   - --audit-webhook-batch-max-wait=1s
```

Warte auf die Wiederherstellung der API und führe eine auditierte Anfrage aus:

```bash
# Terminal 2: wiederhole readyz, bis es "ok" zurückgibt, dann die auditierte Anfrage
kubectl get --raw=/readyz
kubectl get configmap audit-config -n runtime-112 -o json >/dev/null
```

Prüfe, dass der webhook das Ereignis an den Empfänger zugestellt hat:

```bash
# Terminal 2
sleep 3
RECEIVER_POD=$(kubectl get pod -n runtime-112 -l app=audit-receiver -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n runtime-112 "$RECEIVER_POD" --tail=50 | grep -A5 objectRef
```

Zwischenprüfung:

```bash
check_result
```

## 9. Integrationsaufgabe: admission über containerd umgehen und über Falco erkennen

Diese Aufgabe verbindet Supply Chain Security (Lab 111, Kapitel 26) mit der Runtime Security dieser
Lab: Die admission-Prüfung (Kyverno) sieht einen Container nicht, wenn er direkt über
containerd erstellt wurde und kube-apiserver umgeht. Falco arbeitet im Unterschied zum admission controller auf
der Ebene der kernel syscalls und sieht **alle** Container auf dem Node, unabhängig davon, wie sie
gestartet wurden.

**Wichtig: Verwechsle das nicht mit Lab 111.** Dort prüft die policy die kryptografische Signatur
(Cosign). Hier prüft die policy nur die registry/repository allowlist - eine einfachere
admission control ohne signature/attestor. Das gemeinsame Prinzip ist für beide dasselbe: admission arbeitet
nur auf dem API admission path.

Die Namen der lab-owned local registry sind vom bootstrap vorbereitet (nicht das öffentliche Docker Hub - die controlled
abuse fixture dieser Aufgabe muss safe und lab-owned sein und darf nicht von der Verfügbarkeit einer externen
registry zum Zeitpunkt der Prüfung abhängen). Sie liegen in `/etc/cks112/registry.env` auf der control-plane; binde
sie in beiden Terminals ein:

```bash
# Terminal 1 (control-plane, root)
source /etc/cks112/registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
START_TS=$(date '+%Y-%m-%d %H:%M:%S')     # Startzeitpunkt des Durchlaufs
install-kyverno
```

```bash
# Terminal 2
scp control-plane:/etc/cks112/registry.env /tmp/cks112-registry.env
source /tmp/cks112-registry.env
echo "CKS112_REGISTRY=$CKS112_REGISTRY CKS112_TRUSTED_REPO=$CKS112_TRUSTED_REPO"
```

(`install-kyverno` - dieselbe Kyverno-Version wie in Lab 111.)

Wir erstellen eine native `ValidatingPolicy` mit allowlist auf die trusted registry. Wir verwenden die Kyverno CEL
Image library (`image(...).registry()`/`.repository()`) für einen exakten Vergleich und nicht
`startsWith` - sonst würde auch `${CKS112_TRUSTED_REPO}-evil` die policy passieren, weil sein
image string einfach mit dem erlaubten Teilstring beginnt. Die denial-Meldung enthält
den eindeutigen Marker `CKS112_TRUSTED_REPO_POLICY`, damit BATS später gerade diese
policy von jedem anderen admission webhook/jeder anderen policy im Cluster unterscheiden kann:

```bash
# Terminal 2
kubectl apply -f - <<YAML
apiVersion: policies.kyverno.io/v1
kind: ValidatingPolicy
metadata:
  name: require-trusted-registry-runtime-112
spec:
  matchConstraints:
    resourceRules:
    - apiGroups: [""]
      apiVersions: ["v1"]
      resources: ["pods", "pods/ephemeralcontainers"]
      operations: ["CREATE", "UPDATE"]
  matchConditions:
  - name: only-runtime-112
    expression: "object.metadata.namespace == 'runtime-112'"
  validations:
  - expression: >
      object.spec.containers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}') &&
      (!has(object.spec.initContainers) || object.spec.initContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}')) &&
      (!has(object.spec.ephemeralContainers) || object.spec.ephemeralContainers.all(c,
        image(c.image).registry() == '${CKS112_REGISTRY}' &&
        image(c.image).repository() == '${CKS112_TRUSTED_REPO}'))
    message: "CKS112_TRUSTED_REPO_POLICY: only ${CKS112_TRUSTED_IMAGE} is allowed in runtime-112"
  validationActions: [Deny]
YAML
```

Wir bestätigen das admission denial für ein Image außerhalb der allowlist:

```bash
# Terminal 2 (warte nach dem Erstellen der policy etwa 10 Sekunden)
kubectl apply -n runtime-112 -f - > /var/work/tests/artifacts/9/admission-deny.txt 2>&1 <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: blocked-attempt
spec:
  containers:
  - name: app
    image: ${CKS112_UNTRUSTED_IMAGE}
    imagePullPolicy: IfNotPresent
    command: ["sleep", "60"]
YAML
cat /var/work/tests/artifacts/9/admission-deny.txt
# Error from server: ... CKS112_TRUSTED_REPO_POLICY: only ... is allowed in runtime-112
```

Jetzt modellieren wir den Pfad, den der admission controller nicht sieht: Der Container wird direkt
in der container runtime über CRI erstellt und umgeht kube-apiserver vollständig. Dafür gibt es auf der control-plane
den Helper `cks112-run <Image> <id> '<Befehl>'` (ein Wrapper um `crictl runp/create/start`) und
`cks112-rm <id>` zum Aufräumen. Warum nicht `ctr run`: Container, die über `ctr` erstellt wurden, sind
CRI nicht bekannt, und Falco schreibt für sie immer `container.image.repository = <NA>` - trusted und
untrusted Images wären nicht unterscheidbar. Einen Container, der über CRI erstellt wurde, sieht Falco mit dem Image.
Jeder Start erhält ein eindeutiges Suffix `$RUN_ID`, und alle dabei erstellten IDs verwenden
dieses Suffix, daher stößt ein erneuter Durchlauf nicht auf Reste des vorherigen Versuchs:

```bash
# Terminal 1 (control-plane, root)
RUN_ID="$(date +%s%N)"
BYPASS_1="cks112-bypass-1-$RUN_ID"
OBSERVE_REPO="cks112-observe-repo-$RUN_ID"
PROBE_ALLOWED="cks112-probe-allowed-$RUN_ID"
BYPASS_2="cks112-bypass-2-$RUN_ID"
PREFIX_TRAP="cks112-prefix-trap-$RUN_ID"

# CKS112_UNTRUSTED_IMAGE ist nach dem bootstrap bereits im lokalen containerd-Speicher - pull ist nicht nötig.
cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_1 'echo CKS112_CTR_BYPASS; sleep 5'
```

> `container.id != host` ist zwingend: Der Befehl `cks112-run ... 'echo CKS112_CTR_BYPASS'` wird selbst
> auf dem Host gestartet, und seine command line enthält den marker. Ohne diese Bedingung würde die Regel
> beim Host-Startprozess auslösen (sein repository ist leer, also nicht gleich trusted),
> und selbst ein vertrauenswürdiges Image würde einen falschen alert erzeugen.
>
> Falco zeigt für das Image nicht das Tag, mit dem der Container gestartet wurde, sondern den alphabetisch ersten
> Namen des Images (ein Image kann mehrere Namen haben). Daher verwenden die Namen der Lab-Images den
> registry-Host `cks112.local:5000`, der vor `docker.io` einsortiert wird.

Bevor wir die exakte Bedingung schreiben, bestimmen wir den REALEN observed-Wert von
`%container.image.repository` für das vertrauenswürdige Image auf diesem containerd/Falco-Stack -
wir nehmen ihn nicht vorab an. Verschiedene container runtime-/Falco-Versionen können dieses Feld unterschiedlich
bilden (mit dem Hostnamen der registry oder ohne), daher ist der einzig zuverlässige
Weg, den vertrauenswürdigen Container mit einer temporären observe-Regel zu starten und zu sehen, was
Falco tatsächlich schreibt:

```bash
# Terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Observe Trusted Repository Value
  desc: Temporary rule to capture the exact observed container.image.repository string for the trusted image
  condition: spawned_process and container.id != host and proc.cmdline contains "CKS112_OBSERVE_REPO"
  output: "CKS112 observed repository=%container.image.repository tag=%container.image.tag"
  priority: INFORMATIONAL
EOF
systemctl restart falco && sleep 10

# CKS112_TRUSTED_IMAGE ist nach dem bootstrap bereits lokal vorhanden - pull ist nicht nötig.
cks112-run $CKS112_TRUSTED_IMAGE $OBSERVE_REPO 'echo CKS112_OBSERVE_REPO; sleep 5'
sleep 3
TRUSTED_REPO=$(journalctl -u falco-modern-bpf -b --no-pager -n 50 | grep -oP 'CKS112 observed repository=\K[^ ]+' | tail -1)
echo "TRUSTED_REPO=$TRUSTED_REPO"
cks112-rm $OBSERVE_REPO
```

Speichere den Wert `$TRUSTED_REPO` (zum Beispiel `cks112/trusted` oder
`cks112.local:5000/cks112/trusted` - gerade das, was deine Falco-/containerd-Version
tatsächlich ausgegeben hat) als evidence, damit die Bedingung unten überprüfbar an den beobachteten Wert
gebunden ist und nicht an eine Annahme:

```bash
# Terminal 1
echo "$TRUSTED_REPO" > /tmp/art/9/observed-trusted-repo.txt
cat /tmp/art/9/observed-trusted-repo.txt
```

Jetzt fügen wir die abschließende Regel nach der temporären observe-Regel hinzu (`>>`, ohne
die Datei zu überschreiben, um die Regeln aus den Aufgaben 3 und 7 nicht zu verlieren). Die Bedingung verwendet den **exakten**
Vergleich mit dem beobachteten `$TRUSTED_REPO` und keine `startswith`/prefix-Prüfung:
`not container.image.repository startswith "$TRUSTED_REPO"` würde ein Repository wie
`<TRUSTED_REPO>-evil` durchlassen (nicht bemerken), weil sein Name einfach mit dem erlaubten
Teilstring BEGINNT - das heißt, Falco würde es für einen Teil der allowlist halten, obwohl es tatsächlich außerhalb des zulässigen
repository liegt. Das ist dieselbe Falle, die die Kyverno policy oben durch `==` statt
`startsWith` vermeidet; die Bedingung von admission und die Bedingung von Falco müssen dieselbe repository
property auf dieselbe (exakte) Weise und mit demselben beobachteten Wert prüfen, sonst sind sie
als security control nicht äquivalent:

```bash
# Terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF

- rule: CKS112 Runtime Bypass of Admission
  desc: Process spawned in a container whose image is outside the runtime-112 trusted registry allowlist, indicating a container started outside kube-apiserver/admission (e.g. via crictl/CRI directly)
  condition: >
    spawned_process and
    container.id != host and
    proc.cmdline contains "CKS112_CTR_BYPASS" and
    container.image.repository != "$TRUSTED_REPO"
  output: >
    CKS112 runtime bypass of admission detected
    (command=%proc.cmdline container_id=%container.id
    repo=%container.image.repository tag=%container.image.tag
    pid=%proc.pid ppid=%proc.ppid user=%user.name)
  priority: CRITICAL
  tags: [cks112, supply_chain, admission_bypass]
EOF
systemctl restart falco && sleep 10
```

Bevor wir den bypass mit dem untrusted-Image wiederholen, prüfen wir beide kontrollierten Fälle, um
zu belegen, dass der Vergleich tatsächlich exakt und nicht prefix-basiert ist. Zuerst das vertrauenswürdige Image - bei ihm
darf es keinen alert geben (negative control):

```bash
# Terminal 1 (control-plane, root)
cks112-run $CKS112_TRUSTED_IMAGE $PROBE_ALLOWED 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F 'CKS112_CTR_BYPASS' > /tmp/art/9/probe-trusted.log
wc -l < /tmp/art/9/probe-trusted.log        # 0: kein alert für das erlaubte repository
cks112-rm $PROBE_ALLOWED
```

Wir entfernen den ersten container/task vor der Wiederholung, um keinen "hängenden" Prozess zu hinterlassen, und
starten den zweiten mit einer neuen eindeutigen ID - für ihn muss es einen alert geben:

```bash
# Terminal 1 (control-plane, root)
cks112-rm $BYPASS_1

cks112-run $CKS112_UNTRUSTED_IMAGE $BYPASS_2 'echo CKS112_CTR_BYPASS; sleep 5'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep 'CKS112 runtime bypass of admission' > /tmp/art/9/falco-bypass-attempt.log
cp /tmp/art/9/falco-bypass-attempt.log /tmp/art/9/probe-untrusted.log
cks112-rm $BYPASS_2
```

Schließlich belegen wir den prefix-trap selbst: Ein repository, das als `${TRUSTED_REPO}-evil` aufgebaut ist,
BEGINNT mit demselben Teilstring wie das erlaubte `$TRUSTED_REPO`, ist ihm aber nicht exakt gleich.
Würde die Falco condition `startswith` verwenden (wie in der naiven Variante
dieser Regel), würde dieses Image UNBEMERKT durchgehen - gerade deshalb muss die korrigierte Bedingung
`!=` es erkennen. Das Image des prefix-trap ist vom bootstrap vorbereitet (`$CKS112_PREFIX_IMAGE`,
ein separater digest):

```bash
# Terminal 1 (control-plane, root)
cks112-run $CKS112_PREFIX_IMAGE $PREFIX_TRAP 'sleep 2; echo CKS112_CTR_BYPASS; sleep 6'
sleep 3
journalctl -u falco-modern-bpf --since "$START_TS" --no-pager | grep -F 'CKS112 runtime bypass of admission' | grep -F "${TRUSTED_REPO}-evil" > /tmp/art/9/probe-prefix.log
cat /tmp/art/9/probe-prefix.log >> /tmp/art/9/falco-bypass-attempt.log
cks112-rm $PREFIX_TRAP
```

```bash
# Terminal 2: Dateien von Aufgabe 9 abholen
scp 'control-plane:/tmp/art/9/*' /var/work/tests/artifacts/9/
```

> **Struktur der evidence-Dateien von Aufgabe 9.** `falco-bypass-attempt.log` ist das wichtigste
> zusammengeführte artifact, das die automatische Abnahme prüft (es enthält beide alerts:
> untrusted und prefix-trap, darf aber keinen alert für das trusted repo enthalten). Zusätzlich
> schreibt jede probe eine eigene Datei für die manuelle Diagnose: `probe-trusted.log` (muss
> leer sein - das ist gerade die negative control), `probe-untrusted.log` und `probe-prefix.log`.

Die zentrale Erkenntnis dieser Aufgabe: Die registry allowlist bei admission und Falco zur runtime sind keine
austauschbaren, sondern sich ergänzende Schichten. Admission stoppt den Pfad über die Kubernetes
API, weiß aber nichts über Prozesse, die direkt über die container runtime auf dem Node gestartet wurden;
Falco kann die Erstellung eines solchen Containers nicht im Voraus **blockieren**, sieht ihn aber nach dem
Start unabhängig davon, welche API (oder deren Fehlen) verwendet wurde. Dasselbe Prinzip
gilt für die signature verification in Lab 111 - der Unterschied ist nur, dass dort die policy
die Signatur prüft und hier einfach registry/repository. Eine zusätzliche Erkenntnis aus der
prefix-trap-Prüfung oben: Falco condition und Kyverno CEL policy müssen DIESELBE
Vergleichssemantik verwenden (`==`/`!=` und nicht `startsWith`/prefix), sonst sind sie nicht mehr
äquivalente security controls, selbst wenn beide formal "dasselbe" repository prüfen.

## 10. Zugriff auf `/dev/mem` über eine file/device-open condition erkennen

Die Aufgaben 3, 7 und 9 bauten die condition um `spawned_process`/`proc.cmdline` auf - Erkennung
anhand des STARTS eines Prozesses und seiner Argumente. Hier wird eine grundsätzlich andere Klasse
von Falco-Bedingung verwendet: Erkennung anhand des ÖFFNENS einer konkreten Datei/eines Geräts, unabhängig davon,
welcher Prozess das tut und mit welchen Argumenten der Kommandozeile.

Das Deployment `mem-scanner` (2 Replicas) ist vom bootstrap bereits bereitgestellt; beide Replicas öffnen periodisch
`/dev/mem` innerhalb des Containers. Der Pfad `/dev/mem` innerhalb des Containers ist eine synthetic
safe fixture (das backing device ist tatsächlich das host `/dev/null` und nicht der reale physische
Speicher des Hosts); für die Falco-Bedingung nach dem Dateinamen (`fd.name = /dev/mem`) ist das nicht unterscheidbar -
erkannt wird der Systemaufruf `open`/`openat`/`openat2` selbst. Füge die Regel auf der
`control-plane` hinzu:

```bash
# Terminal 1 (control-plane, root)
cat >> /etc/falco/falco_rules.local.yaml <<EOF
- rule: CKS112 Container access to /dev/mem
  desc: Detect an open of /dev/mem from a container process
  condition: >
    evt.type in (open, openat, openat2) and
    fd.name = /dev/mem and
    container.id != host
  output: >
    CKS112 Container access to /dev/mem
    (container_id=%container.id k8s_pod=%k8s.pod.name k8s_ns=%k8s.ns.name
    proc=%proc.name pid=%proc.pid user=%user.name)
  priority: CRITICAL
  tags: [container, mitre_privilege_escalation, mitre_defense_evasion]
EOF
systemctl restart falco && sleep 10
```

Warte auf den nächsten periodischen Zyklus von `mem-scanner` (alle ~15 Sekunden) und finde die
Auslösung. Nimm den Identifikator des Pods AUS dem alert selbst (`k8s_pod=`) und rate nicht
vorab, welche der beiden Replicas schuldig ist - das ist dieselbe Grundregel "beginne mit dem
alert" wie in Aufgabe 6:

```bash
# Terminal 1 (control-plane, root)
journalctl -u falco-modern-bpf -b --no-pager -n 500 | grep -F 'CKS112 Container access to /dev/mem' | tail -1 > /tmp/art/10/falco-devmem.log
cat /tmp/art/10/falco-devmem.log
exit   # aus root
exit   # von der control-plane
```

```bash
# Terminal 2
scp control-plane:/tmp/art/10/falco-devmem.log /var/work/tests/artifacts/10/
```

Nachdem die Erkennung von Falco selbst bestätigt wurde (und nicht durch das Pod manifest), speichere den im alert
genannten Pod und überzeuge dich, dass er vor dem Skalieren tatsächlich zum ReplicaSet des Deployment
`mem-scanner` gehört:

```bash
# Terminal 2
ALERT_POD=$(sed -n 's/.*k8s_pod=\([^ ]*\).*/\1/p' /var/work/tests/artifacts/10/falco-devmem.log | tail -1)
echo "$ALERT_POD"
kubectl get pod "$ALERT_POD" -n runtime-112 -o json > /var/work/tests/artifacts/10/detected-pod.json
```

Dann stoppen wir den workload:

```bash
# Terminal 2
kubectl scale deployment mem-scanner -n runtime-112 --replicas=0
kubectl get deployment mem-scanner -n runtime-112 -o json > /var/work/tests/artifacts/10/scaled-down.json
jq '.spec.replicas' /var/work/tests/artifacts/10/scaled-down.json
# erwartet: 0
```

`container.id != host` in der Bedingung ist kein dekoratives Detail: Ohne sie würde die Regel
auch bei legitimen Systemprozessen des Nodes (zum Beispiel Werkzeugen zur Speicherdiagnose) auslösen,
die außerhalb von Containern laufen, und auf jedem Node des Clusters laute false positives erzeugen.

Führe am Ende `check_result` aus.
