[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 110 - Referenzlösung: gVisor, WireGuard und Istio STRICT

> Wir arbeiten wie in der Prüfung: `kubectl`, `cilium` und `istioctl` - auf der Arbeitsmaschine, und Operationen am
> Node (containerd, tcpdump) - auf dem Node selbst: Melde dich dort mit `ssh <Node>` an, werde root
> (`sudo -i`), führe die Befehle aus und verlasse ihn wieder (`exit`, `exit`). Die Namen `gvisor-sandbox`,
> `runc-baseline`, `gvisor-echo`, `market-api`, `market-client`, `mesh-outside` und die Pfade der
> artifacts sind Teil des prüfbaren Vertrags der Lab.

## Wo du Beispiele in der Dokumentation findest

| Was gebraucht wird | Seite und Abschnitt |
| :--- | :--- |
| Der Abschnitt `runsc` in `/etc/containerd/config.toml` (`runtime_type = "io.containerd.runsc.v1"`), Neustart von containerd und YAML `RuntimeClass` mit `handler: runsc` | [gVisor - Containerd Quick Start: Configure containerd, Restart containerd, Set up the Kubernetes RuntimeClass](https://gvisor.dev/docs/user_guide/containerd/quick_start/) |
| `RuntimeClass`, die Felder `scheduling.nodeSelector` und `scheduling.tolerations` | [Kubernetes - Runtime Class: Scheduling](https://kubernetes.io/docs/concepts/containers/runtime-class/#scheduling) |
| WireGuard aktivieren (`encryption.enabled=true`, `encryption.type=wireguard`) und prüfen (`cilium-dbg status \| grep Encryption`) | [Cilium - WireGuard Transparent Encryption: Enable WireGuard in Cilium, Validate the Setup](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/) |
| `PeerAuthentication` mit `mtls.mode: STRICT` | [Istio - PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/) |

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
export CTX=cluster1-admin@cluster1
kubectl config use-context "$CTX"
mkdir -p /var/work/tests/artifacts/{1,2,3,4,5,6}
```

## 1. containerd runtime wiederherstellen und RuntimeClass erstellen

Der Node `k8s110_node_gvisor` wird bereits als dedicated pool mit installiertem `runsc` geliefert, aber
der bootstrap hat absichtlich den runtime-Abschnitt `runsc` aus `/etc/containerd/config.toml` entfernt -
eine typische Prüfungssituation, in der die Binärdatei da ist, containerd aber nichts davon weiß.

```bash
ssh k8s110_node_gvisor
sudo -i
```

```bash
# auf dem gVisor-Node (root): die Binärdatei ist da, containerd ist aktiv, der Abschnitt runsc fehlt in der Config
runsc --version
systemctl is-active containerd
grep runsc /etc/containerd/config.toml

# den Abschnitt runsc ergänzen (der Wert von runtime_type muss exakt sein) und containerd neu starten
cat >> /etc/containerd/config.toml <<EOF
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runsc]
  runtime_type = "io.containerd.runsc.v1"
EOF
systemctl restart containerd
systemctl is-active containerd
grep -A1 runtimes.runsc /etc/containerd/config.toml
exit   # aus root
exit   # vom gVisor-Node
```

Das Kubelet muss nicht neu gestartet werden: `RuntimeClass` ruft den containerd runtime handler beim
Erstellen jedes Pods über den Namen auf und nicht beim Start des kubelet.

```yaml
# runtimeclass-gvisor.yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: runsc
scheduling:
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
```

```bash
kubectl apply -f runtimeclass-gvisor.yaml
kubectl get runtimeclass gvisor -o yaml
printf 'RuntimeClass gvisor: handler runsc\n' \
  > /var/work/tests/artifacts/1/runsc-runtime.txt
```

`scheduling.nodeSelector` ist eine wichtige Grenze: Der scheduler weist einen `runsc` workload nicht der
control-plane zu, wo es einen solchen handler nicht gibt. Der gVisor-Node ist dabei mit dem taint
`sandbox.runtime/gvisor=true:NoSchedule` markiert (`kubectl describe node <gvisor-Node> | grep Taints`):
Auf ihn gelangt kein einziger Pod, außer denen, die ihn tolerieren. `scheduling.tolerations` in der RuntimeClass
werden automatisch allen Pods mit dieser Klasse hinzugefügt, daher gelangt `gvisor-sandbox` dorthin,
und die übrigen nicht.

## 2. Sandboxed Pod und Service starten

`busybox httpd` liefert zugleich eine shell für `uname` und einen kleinen HTTP endpoint für das
WireGuard-Experiment zwischen Nodes. `runtimeClassName` wird auf den Pod und nicht auf den Container angewendet.

`nodeSelector` und `tolerations` sind im Pod explizit gesetzt: So sieht man, auf welchen Node er gelangt und warum.
Das ist dasselbe, was in `scheduling` der `RuntimeClass` selbst beschrieben ist. Wenn man sie im Pod nicht angibt,
geht nichts kaputt: Beim Erstellen eines Pods mit `runtimeClassName` **fügt** Kubernetes ihm selbst
`nodeSelector` und `tolerations` aus `RuntimeClass.scheduling` **hinzu** (prüfen: `kubectl -n sandbox-110 get
pod gvisor-sandbox -o jsonpath='{.spec.nodeSelector}'`). Aber dann ist das im Manifest nicht zu sehen, und ohne
`scheduling` in der RuntimeClass könnte der Pod auf einem Node ohne `runsc` landen und nicht starten.

```yaml
# gvisor-sandbox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gvisor-sandbox
  namespace: sandbox-110
  labels:
    app: gvisor-echo
spec:
  runtimeClassName: gvisor
  nodeSelector:
    sandbox.runtime/gvisor: "true"
  tolerations:
  - key: sandbox.runtime/gvisor
    operator: Equal
    value: "true"
    effect: NoSchedule
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command:
    - sh
    - -ec
    - |
      mkdir -p /www
      printf 'CKS110-WIREGUARD-MARKER\n' >/www/index.html
      exec httpd -f -p 8080 -h /www
    ports:
    - containerPort: 8080
      name: http
---
apiVersion: v1
kind: Service
metadata:
  name: gvisor-echo
  namespace: sandbox-110
spec:
  selector:
    app: gvisor-echo
  ports:
  - name: http
    port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f gvisor-sandbox.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/gvisor-sandbox --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf '\n--- gvisor dmesg ---\n'
  kubectl exec -n sandbox-110 gvisor-sandbox -- dmesg 2>&1 || true
} > /var/work/tests/artifacts/2/gvisor-kernel.txt
cat /var/work/tests/artifacts/2/gvisor-kernel.txt
kubectl get pod -n sandbox-110 gvisor-sandbox -o wide
```

Der gVisor Sentry zeigt dem workload einen synthetischen kernel view; `dmesg` kann
eingeschränkt sein. Das ist erwartet und kein Grund, dem Container überflüssige privileges zu geben.

## 3. Gewöhnlicher runc Pod zum Vergleich

Das Fehlen von `runtimeClassName` belässt den default handler `runc`. Der selector platziert
diesen Pod absichtlich auf der control-plane, daher erzeugen die folgenden Aufgaben Traffic
zwischen Nodes.

```yaml
# runc-baseline.yaml
apiVersion: v1
kind: Pod
metadata:
  name: runc-baseline
  namespace: sandbox-110
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f runc-baseline.yaml
kubectl wait -n sandbox-110 --for=condition=Ready pod/runc-baseline --timeout=180s
{
  printf 'gvisor uname -r: '
  kubectl exec -n sandbox-110 gvisor-sandbox -- uname -r
  printf 'runc uname -r: '
  kubectl exec -n sandbox-110 runc-baseline -- uname -r
} > /var/work/tests/artifacts/3/runtime-comparison.txt
cat /var/work/tests/artifacts/3/runtime-comparison.txt
```

Ein gewöhnlicher `runc` Container sieht das host kernel release, ein gVisor workload - den Sentry view.
Das ist eine zusätzliche Ausführungsgrenze und kein Ersatz für `SecurityContext`, seccomp oder
die Prüfung des Images.

## 4. Cilium WireGuard aktivieren

Cilium verwaltet WireGuard keys und peers selbst. Wir aktivieren ein Verschlüsselungs-Backend -
IPsec fügen wir nicht hinzu. Wichtig: Das **Client**-`cilium` CLI (auf dem worker installiert) hat keinen
Unterbefehl `encrypt enable`; WireGuard wird über die Cilium-Konfiguration aktiviert und nicht über einen
runtime-Befehl. Zuerst halten wir die Versionen fest und gleichen den agent mit der requirements matrix ab:

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf 'Kubernetes='
  kubectl version -o json | jq -r '.serverVersion.gitVersion'
  printf 'Cilium agent='
  kubectl -n kube-system get pod "$agent" -o jsonpath='{.spec.containers[?(@.name=="cilium-agent")].image}'
  printf '\n'
  cilium version --client
  printf 'Cilium CLI=v0.19.7\n'
  printf 'Cilium data plane=verify current supported lab build against Kubernetes 1.36 requirements matrix\n'
  printf 'Istio=1.30.4\n'
} > /var/work/tests/artifacts/4/tool-versions.txt
cat /var/work/tests/artifacts/4/tool-versions.txt
```

Der Cluster wurde mit dem Befehl `cilium install` ausgerollt, der Cilium **über Helm** installiert.
Die langfristige source of truth sind die Helm values des release `cilium`; wir verwenden ein festgelegtes Cilium-CLI-upgrade und prüfen danach die live ConfigMap und die agents:

```bash
cilium upgrade --version 1.20.1 \
  --set encryption.enabled=true --set encryption.type=wireguard --wait
# Helm ändert nur die ConfigMap: Das Template des DaemonSet ändert sich nicht, daher starten die Agents
# nicht von selbst neu und arbeiten ohne WireGuard weiter - starte sie explizit neu.
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
test "$(kubectl -n kube-system get cm cilium-config -o jsonpath='{.data.enable-wireguard}')" = true
cilium status --wait
```

Den Verschlüsselungsstatus lesen wir beim Agent über `cilium-dbg`: Das ist das in-pod debug CLI, das mit dem Cilium agent ausgeliefert wird. Das lokale `cilium` CLI bleibt ein install/cluster-level Werkzeug und ersetzt es innerhalb des Pods nicht. `cilium-dbg status` hat KEIN Flag `--all-encryption` (in 1.20.x gibt es nur `--all-addresses`, `--all-clusters`, `--all-controllers`, `--all-health`, `--all-nodes`, `--all-redirects`, `--verbose`) - detaillierte peer/allowed-IP/remote-node evidence erhalten wir über `cilium-dbg debuginfo --output json` und nicht über ein nicht existierendes Flag.

```bash
agent=$(kubectl -n kube-system get pods -l k8s-app=cilium -o jsonpath='{.items[0].metadata.name}')
{
  printf '$ cilium-dbg encrypt status
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg encrypt status
  printf '$ cilium-dbg debuginfo --output json
'
  kubectl -n kube-system exec "$agent" -- cilium-dbg debuginfo --output json
} > /var/work/tests/artifacts/4/cilium-encrypt-status.txt
cat /var/work/tests/artifacts/4/cilium-encrypt-status.txt
grep -Eqi 'peer|allowed[ -]?ip|remote node' /var/work/tests/artifacts/4/cilium-encrypt-status.txt
```

## 5. Mitschnitt eines WireGuard-Pakets zwischen Nodes

WireGuard verwendet standardmäßig UDP/51871. Ein Filter NUR nach `udp port 51871` schließt plaintext TCP vorab
aus dem Ergebnis aus und beweist daher sein Fehlen NICHT - stattdessen
verwenden wir denselben Capture-Scope (`host <remote-node-ip>`, ohne Port-Filter) und vergleichen
VORHER/NACHHER beim Aktivieren von WireGuard für denselben Flow zwischen Nodes.

Ein Capture auf `any` ist KEIN korrekter Beobachtungspunkt für den on-wire state: `any` sieht auch das interne
Cilium-Interface `cilium_wg0`, über das konstruktionsbedingt des Tunnels BEREITS ENTSCHLÜSSELTER
Traffic läuft. Mitgeschnitten werden muss das physische egress-Interface zum entfernten Node (nicht `any`, `cilium_*`,
`lxc*`, `veth*`).

Du brauchst zwei Terminals: **Terminal 1** - control-plane (dort `tcpdump`), **Terminal 2** -
Arbeitsmaschine (Anfragen und `kubectl`).

```bash
# Terminal 2 (Arbeitsmaschine): IP des Nodes mit dem gVisor-Pod - das ist der "entfernte" Node für die control-plane
gvisor_node=$(kubectl get pod gvisor-sandbox -n sandbox-110 -o jsonpath='{.spec.nodeName}')
remote_ip=$(kubectl get node "$gvisor_node" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "remote_ip=$remote_ip"
```

```bash
# Terminal 1: auf die control-plane gehen und das physische Interface zu remote_ip herausfinden
ssh k8s110_controlPlane_1
sudo -i
```

```bash
# Terminal 1 (control-plane, root): trage den Wert von remote_ip aus Terminal 2 ein
remote_ip=10.110.2.172
ip route get $remote_ip
# 10.110.2.172 dev ens5 src 10.110.1.x   <- das Interface (ens5), nicht any / cilium_* / lxc* / veth*
```

**Baseline: WireGuard aus.** Wir deaktivieren WireGuard vorübergehend und wiederholen DIESELBE Anfrage mit DEMSELBEN
Capture-Scope. Am Ende stellen wir unbedingt `enable-wireguard: "true"` wieder her.

```bash
# Terminal 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"false"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# Terminal 1 (control-plane, root): 20 Sekunden mitschneiden, dann sofort die Anfrage in Terminal 2 starten
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-baseline.txt
```

```bash
# Terminal 2: während der Mitschnitt läuft (in den ersten ~15 Sekunden)
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# Terminal 1 (nach Ende des Mitschnitts): der plaintext marker ist sichtbar, WireGuard ist aus
grep CKS110-WIREGUARD-MARKER /tmp/wireguard-baseline.txt
```

**Nachher: WireGuard an.** Wir stellen WireGuard wieder her und wiederholen DIESELBE Anfrage mit DEMSELBEN Scope
des Mitschnitts: Jetzt muss WireGuard UDP/51871 sichtbar sein und der marker darf nicht vorkommen.

```bash
# Terminal 2
kubectl -n kube-system patch cm cilium-config --type merge -p '{"data":{"enable-wireguard":"true"}}'
kubectl -n kube-system rollout restart daemonset/cilium
kubectl -n kube-system rollout status daemonset/cilium --timeout=180s
```

```bash
# Terminal 1 (control-plane, root): 20 Sekunden mitschneiden
timeout 20 tcpdump -nni ens5 host $remote_ip -A > /tmp/wireguard-tcpdump.txt
```

```bash
# Terminal 2: während der Mitschnitt läuft
kubectl exec -n sandbox-110 runc-baseline -- \
  wget -qO- --timeout=10 http://gvisor-echo.sandbox-110.svc.cluster.local:8080
```

```bash
# Terminal 1 (nach Ende des Mitschnitts)
grep -E 'UDP' /tmp/wireguard-tcpdump.txt | head -3      # 51871 > 51871: UDP
grep -c CKS110-WIREGUARD-MARKER /tmp/wireguard-tcpdump.txt   # 0
exit   # aus root
exit   # von der control-plane
```

```bash
# Terminal 2: den Capture für die Prüfung abholen
scp k8s110_controlPlane_1:/tmp/wireguard-tcpdump.txt /var/work/tests/artifacts/5/wireguard-tcpdump.txt
```

Ziehe keine Schlüsse aus `tcpdump` im Pod netns: Dort kann der Traffic vor dem Cilium encryption point noch
plaintext sein. Der Nachweis ist hier der Übergang vom sichtbaren marker (WireGuard ausgeschaltet) zu seinem
Fehlen (WireGuard eingeschaltet) bei EIN UND DEMSELBEN Capture-Scope.

## 6. Istio und PeerAuthentication STRICT

Wir installieren nur die Istio control plane im minimal profile. Der Namespace wurde mit
`istio-injection=enabled` vorbereitet, daher erhalten workloads in `market` beim
Erstellen einen Envoy sidecar. `market-api` liegt auf dem gVisor worker, der client - auf der control-plane, was
die Anfrage ebenfalls zu einer Anfrage zwischen Nodes macht.

```bash
istioctl install --set profile=minimal -y
kubectl -n istio-system rollout status deployment/istiod --timeout=180s
kubectl get namespace market --show-labels
```

```yaml
# market-workloads.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-api
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-api}
  template:
    metadata:
      labels: {app: market-api}
    spec:
      nodeSelector:
        lab.cks.io/role: gvisor
      tolerations:
      - key: sandbox.runtime/gvisor
        operator: Equal
        value: "true"
        effect: NoSchedule
      automountServiceAccountToken: false
      containers:
      - name: app
        image: busybox:1.36
        command: ["sh", "-ec", "mkdir -p /www; printf 'market-110\\n' >/www/index.html; exec httpd -f -p 8080 -h /www"]
        ports:
        - containerPort: 8080
          name: http
        readinessProbe:
          httpGet:
            path: /
            port: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: market-api
  namespace: market
spec:
  selector: {app: market-api}
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: market-client
  namespace: market
spec:
  replicas: 1
  selector:
    matchLabels: {app: market-client}
  template:
    metadata:
      labels: {app: market-client}
    spec:
      nodeSelector:
        lab.cks.io/role: control-plane
      automountServiceAccountToken: false
      containers:
      - name: app
        image: curlimages/curl:8.11.0
        command: ["sh", "-c", "sleep 3600"]
---
apiVersion: v1
kind: Pod
metadata:
  name: mesh-outside
  namespace: default
spec:
  nodeSelector:
    lab.cks.io/role: control-plane
  automountServiceAccountToken: false
  containers:
  - name: app
    image: curlimages/curl:8.11.0
    command: ["sh", "-c", "sleep 3600"]
```

```bash
kubectl apply -f market-workloads.yaml
kubectl rollout status -n market deployment/market-api --timeout=180s
kubectl rollout status -n market deployment/market-client --timeout=180s
kubectl wait -n default --for=condition=Ready pod/mesh-outside --timeout=180s
kubectl get pods -n market

# Baseline (STRICT ist noch nicht angewendet): Ein plaintext client außerhalb des mesh muss 200 erhalten -
# das beweist, dass die Konnektivität grundsätzlich funktioniert und jede spätere Ablehnung
# gerade von STRICT mTLS verursacht wird und nicht von einem unabhängigen DNS/Netzwerk-Problem.
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside-baseline.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside-baseline.txt
cat /var/work/tests/artifacts/6/market-outside-baseline.txt
# erwartet: HTTP/1.1 200 OK und am Ende exit_code=0
```

```yaml
# market-strict.yaml
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: market-strict
  namespace: market
spec:
  mtls:
    mode: STRICT
```

```bash
kubectl apply -f market-strict.yaml
kubectl get peerauthentication -n market market-strict -o yaml

# Anfrage aus dem Inneren des mesh (client mit sidecar)
kubectl exec -n market deploy/market-client -- \
  curl -si --max-time 10 http://market-api \
  > /var/work/tests/artifacts/6/market-inside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-inside.txt
cat /var/work/tests/artifacts/6/market-inside.txt
# erwartet: HTTP/1.1 200 OK und am Ende exit_code=0

# dieselbe Anfrage von außerhalb des mesh (plaintext, ohne sidecar)
kubectl exec -n default mesh-outside -- \
  curl -sv --max-time 10 http://market-api.market.svc.cluster.local \
  > /var/work/tests/artifacts/6/market-outside.txt 2>&1
echo "exit_code=$?" >> /var/work/tests/artifacts/6/market-outside.txt
cat /var/work/tests/artifacts/6/market-outside.txt
# erwartet: Recv failure: Connection reset by peer und am Ende exit_code=56 (nicht 0)
```

`PeerAuthentication` steuert den inbound server mode. Der interne client erhält ein
Zertifikat und verwendet mTLS automatisch; der Pod in `default` hat keinen sidecar und sendet
plaintext, daher setzt der Envoy server bei `STRICT` die Verbindung zurück. Schließe ab mit:

```bash
check_result
```
