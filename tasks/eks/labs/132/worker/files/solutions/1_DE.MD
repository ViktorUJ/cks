[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 132 - Referenzlösung (Cilium im CNI-Chaining-Modus über VPC CNI)

Alle Befehle werden auf der Worker-Maschine per SSH ausgeführt. kubectl und helm sind
bereits konfiguriert (die kubeconfig wurde beim Start der Maschine über
`aws eks update-kubeconfig` erstellt).

> Cilium-Versionen und die genauen Namen der Values-Flags des Chaining-Modus ändern sich
> zwischen Releases schnell. Die folgenden Befehle wurden auf einem Live-Prüfstand mit
> Cilium `1.20.0` und EKS `1.36` verifiziert. Wenn du eine andere Version verwendest,
> vergleiche die Syntax mit der Cilium-Dokumentation
> (`https://docs.cilium.io/en/stable/installation/cni-chaining-aws-cni/`).

## Aufgabe 1. Namespace `eks-132`

```bash
kubectl create namespace eks-132
```

## Aufgabe 2. Last im Pool `cilium-demo` ohne Cilium

Der NodePool `cilium-demo` existiert bereits als Code (Taint
`dedicated=cilium-demo:NoSchedule`, Label `work_type=cilium-demo`), aber solange kein Pod
mit passender Toleration dort landet, fährt Karpenter keinen einzigen Node hoch. Wir
erstellen das Deployment `api` und `client` sofort mit `nodeSelector` und Toleration, damit
sie genau dort landen:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: eks-132
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: eks-132
spec:
  selector:
    app: api
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: client
  namespace: eks-132
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client
  template:
    metadata:
      labels:
        app: client
    spec:
      nodeSelector:
        work_type: cilium-demo
      tolerations:
        - key: dedicated
          operator: Equal
          value: cilium-demo
          effect: NoSchedule
      containers:
      - name: curl
        image: curlimages/curl:latest
        command: ["sleep", "3600"]
EOF

kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Karpenter fährt einen neuen Node im Pool `cilium-demo` hoch (üblicherweise 60-90
Sekunden). Sobald `rollout status` die Bereitschaft bestätigt, prüfen wir die Konnektivität
über das reguläre VPC CNI - Cilium ist noch nicht installiert:

```bash
mkdir -p /var/work/tests/artifacts/2
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/2/connectivity_before.txt
cat /var/work/tests/artifacts/2/connectivity_before.txt
```

## Aufgabe 3. Cilium über Helm im CNI-Chaining-Modus, nur auf `cilium-demo`

Wir fügen das Cilium-Repository hinzu und bereiten die Values-Datei vor. Der
Schlüsselparameter ist `cni.chainingMode: aws-cni`: VPC CNI (`aws-node`) bleibt das
Haupt-IPAM, Cilium klinkt sich in die Kette ein und fügt eBPF-Programme über der bereits
konfigurierten Pod-Schnittstelle hinzu.

Drei `nodeSelector`/`tolerations`-Blöcke (oberste Ebene für den Agenten, `envoy` und
`operator`) beschränken alle Cilium-Komponenten auf den Pool `cilium-demo`. Der oberste
`nodeSelector` wird nur vom DaemonSet `cilium` übernommen; `cilium-envoy` und
`cilium-operator` haben eigene Abschnitte, und ohne sie bleiben die Envoy-Pods auf allen
anderen Nodes in `Pending` hängen, und `cilium status` zeigt `Envoy DaemonSet: 1 errors`.

Separat deaktivieren wir `operator.unmanagedPodWatcher.restart`. Das ist für diesen
Prüfstand ein obligatorischer Flag, keine Feineinstellung: standardmäßig löscht der
Operator alle 15 Sekunden Pods ohne `CiliumEndpoint`, damit sie neu starten und in die
CNI-Kette gelangen. `coredns`-Pods laufen auf Fargate, wo es keinen Cilium-Agenten gibt und
geben kann, daher werden sie niemals managed - der Operator tötet sie endlos, jedes Mal
einen neuen Fargate-Node hochfahrend, und das DNS im Cluster fällt aus (Details im
Abschnitt „Fallstricke" unten).

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

cat <<'EOF' > /tmp/cilium-values.yaml
cni:
  chainingMode: aws-cni
  exclusive: false
enableIPv4Masquerade: false
routingMode: native
nodeSelector:
  work_type: cilium-demo
tolerations:
  - key: dedicated
    operator: Equal
    value: cilium-demo
    effect: NoSchedule
envoy:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
operator:
  nodeSelector:
    work_type: cilium-demo
  tolerations:
    - key: dedicated
      operator: Equal
      value: cilium-demo
      effect: NoSchedule
  unmanagedPodWatcher:
    restart: false
EOF

helm install cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
```

Die Pods `api` und `client` wurden vor der Installation von Cilium gestartet, daher hat das
CNI-Chaining noch nicht auf sie gewirkt (die Cilium-Dokumentation warnt ausdrücklich
davor: bestehende Pods müssen neu gestartet werden). Wir starten beide Deployments neu:

```bash
kubectl rollout restart deployment/api -n eks-132
kubectl rollout restart deployment/client -n eks-132
kubectl rollout status deployment/api -n eks-132
kubectl rollout status deployment/client -n eks-132
```

Wir installieren die Cilium CLI und prüfen den Status:

```bash
CILIUM_CLI_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
sudo tar xzvfC "cilium-linux-${CLI_ARCH}.tar.gz" /usr/local/bin
rm "cilium-linux-${CLI_ARCH}.tar.gz"

mkdir -p /var/work/tests/artifacts/3
cilium status | tee /var/work/tests/artifacts/3/cilium_status.txt
```

In der Ausgabe sollten `Cilium: OK`, `Operator: OK` und `Envoy DaemonSet: OK` stehen, und
die `Desired`-Zahl beider DaemonSets sollte mit der Anzahl der `cilium-demo`-Nodes
übereinstimmen.

## Aufgabe 4. Beweis des Chaining: Adressen kommen immer noch von VPC CNI

```bash
mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n eks-132 -o wide > /var/work/tests/artifacts/4/podips.txt
cat /var/work/tests/artifacts/4/podips.txt
```

Die IPs der Pods `api` und `client` stammen aus dem CIDR `10.10.0.0/16` - demselben
Bereich wie die VPC selbst. Wäre dies ein vollständiger Ersatz von VPC CNI mit
Overlay-Modus, würden die Adressen aus einem separaten virtuellen Pool (`cluster-pool`)
kommen, nicht aus dem Subnetz des Nodes. Hier ist IPAM bei VPC CNI geblieben - das ist genau
der Kern des Chaining (Chapter 8).

## Aufgabe 5. L7-Richtlinie: nur GET

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-l7-allow-get
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: api
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/.*"
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-l7-allow-get -n eks-132
```

Wir prüfen das erlaubte GET und das blockierte POST:

```bash
mkdir -p /var/work/tests/artifacts/5
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/allowed_get.txt
cat /var/work/tests/artifacts/5/allowed_get.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 8 -X POST \
  -w "HTTP_CODE=%{http_code}\n" http://api.eks-132.svc.cluster.local:8080 \
  > /var/work/tests/artifacts/5/blocked_post.txt || true
cat /var/work/tests/artifacts/5/blocked_post.txt
```

GET geht durch (`HTTP_CODE=200`), POST wird vom Envoy-Proxy von Cilium auf L7-Ebene
blockiert (`HTTP_CODE=403`, Zugriff verweigert, bevor die Anfrage überhaupt die Anwendung
erreicht). Die eingebaute VPC CNI NetworkPolicy hat diesen HTTP-Methoden-Filter nicht - nur
L3/L4 (Chapter 8).

Verwende den vollständigen Namen `ciliumnetworkpolicies.cilium.io`: der Kurzname `cnp` ist
in diesem Cluster mehrdeutig, weil VPC CNI seine eigene Ressource
`clusternetworkpolicies.networking.k8s.aws` mitbringt, und kubectl warnt davor.

## Aufgabe 6. FQDN-Richtlinie: Egress nur zu `aws.amazon.com`

Es gibt zwei Stellen, an denen sich diese Richtlinie anders verhält als das typische
Beispiel in der Dokumentation.

Erstens: die DNS-Regel kann nicht über `toEndpoints` mit dem Label `k8s-app: kube-dns`
geschrieben werden. `toEndpoints` funktioniert über die Cilium-Identität, und die
`coredns`-Pods in diesem Cluster laufen auf Fargate, wo es keinen Cilium-Agenten gibt - sie
haben kein `CiliumEndpoint`, landen nicht im `ipcache` und erscheinen aus Sicht der
Richtlinie als `reserved:world`. Eine Regel nach Label würde niemals matchen, DNS wäre
durch Default-Deny geschlossen, und `curl` könnte den Namen nicht einmal auflösen. Deshalb
erlauben wir DNS per CIDR: den Service-Bereich des Clusters (`172.20.0.0/16`, wo die
`kube-dns` ClusterIP liegt) und den VPC-CIDR (`10.10.0.0/16`, wo die `coredns`-Pods selbst
laufen). L7-Regeln `rules.dns` auf `toCIDRSet` funktionieren wie gewohnt - genau so
dokumentiert Cilium den Fall eines externen DNS-Servers.

Zweitens: der `endpointSelector` auf `app: client` aktiviert Default-Deny für den gesamten
Egress dieses Pods. Wenn wir nur `toFQDNs` und DNS belassen, würde das GET zu `api` aus
Aufgabe 5 kaputtgehen - seine Pakete würden verworfen. Deshalb erlauben wir als dritten
Block explizit Egress zu `api:8080`. So ist der Endzustand des Prüfstands konsistent:
Aufgabe 5 und Aufgabe 6 sind gleichzeitig wahr.

Die Reihenfolge der Blöcke ist wichtig: `toFQDNs` muss an erster Stelle bleiben
(`egress[0]`), genau dort schaut der automatische Test hin.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: cilium-fqdn-allow-aws
  namespace: eks-132
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toFQDNs:
    - matchName: "aws.amazon.com"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
  - toCIDRSet:
    - cidr: 172.20.0.0/16
    - cidr: 10.10.0.0/16
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
  - toEndpoints:
    - matchLabels:
        app: api
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
EOF

kubectl get ciliumnetworkpolicies.cilium.io cilium-fqdn-allow-aws -n eks-132
```

Wir prüfen:

```bash
mkdir -p /var/work/tests/artifacts/6
CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://aws.amazon.com \
  > /var/work/tests/artifacts/6/allowed_fqdn.txt || true
cat /var/work/tests/artifacts/6/allowed_fqdn.txt

kubectl exec -n eks-132 "$CLIENT_POD" -- \
  curl -s -o /dev/null --connect-timeout 5 --max-time 10 \
  -w "HTTP_CODE=%{http_code}\n" https://example.com \
  > /var/work/tests/artifacts/6/blocked_other_domain.txt || true
cat /var/work/tests/artifacts/6/blocked_other_domain.txt
```

`aws.amazon.com` wird aufgelöst und `curl` geht durch - `HTTP_CODE=200`. `example.com` wird
ebenfalls aufgelöst (DNS ist erlaubt), aber die TCP-Sitzung zu seiner Adresse fällt nicht
unter `toFQDNs`, Pakete werden verworfen, und `curl` hängt bis `--max-time` -
`HTTP_CODE=000`. Die eingebaute VPC CNI NetworkPolicy hat überhaupt keine solche
DNS-Namens-Richtlinie - nur `ipBlock` nach IP/CIDR (Chapter 8).

## Aufgabe 7. Hubble: Flow-Observability mit Verdict

Wir aktivieren Hubble relay über dem bereits installierten Cilium, mit demselben
`nodeSelector` auf `cilium-demo`:

```bash
cat <<'EOF' >> /tmp/cilium-values.yaml
hubble:
  relay:
    enabled: true
    nodeSelector:
      work_type: cilium-demo
    tolerations:
      - key: dedicated
        operator: Equal
        value: cilium-demo
        effect: NoSchedule
EOF

helm upgrade cilium cilium/cilium --version 1.20.0 \
  --namespace kube-system \
  -f /tmp/cilium-values.yaml

kubectl -n kube-system rollout status deployment/hubble-relay --timeout=240s
```

Wir installieren die Hubble CLI:

```bash
HUBBLE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/cilium/hubble/main/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all \
  "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${HUBBLE_ARCH}.tar.gz"
sudo tar xzvfC "hubble-linux-${HUBBLE_ARCH}.tar.gz" /usr/local/bin
rm "hubble-linux-${HUBBLE_ARCH}.tar.gz"
```

Wir starten einen Port-Forward zum Relay (`4245`), wiederholen die blockierten Anfragen aus
Aufgabe 5 und 6, um `DROPPED`-Ereignisse zu erhalten, und lesen den Flow:

```bash
setsid nohup kubectl -n kube-system port-forward service/hubble-relay 4245:80 \
  </dev/null >/tmp/pf.log 2>&1 &
sleep 5

CLIENT_POD=$(kubectl get po -n eks-132 -l app=client -o jsonpath='{.items[0].metadata.name}')
for i in 1 2 3; do
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 -X POST \
    http://api.eks-132.svc.cluster.local:8080 >/dev/null 2>&1 || true
  kubectl exec -n eks-132 "$CLIENT_POD" -- \
    curl -s -o /dev/null --connect-timeout 3 --max-time 5 \
    https://example.com >/dev/null 2>&1 || true
done

mkdir -p /var/work/tests/artifacts/7
hubble observe --server localhost:4245 -n eks-132 --last 200 \
  | tee /var/work/tests/artifacts/7/hubble_denied.txt
grep -c DROPPED /var/work/tests/artifacts/7/hubble_denied.txt
```

Starte den Port-Forward unbedingt über `setsid nohup ... </dev/null &`: ein gewöhnliches
`kubectl port-forward &` hängt an der SSH-Sitzung und stirbt, wenn diese abbricht.

In der Datei sollten Zeilen mit dem Verdict `DROPPED` stehen - das sind verworfene SYNs zu
`example.com`-Adressen (`policy-verdict:none ... Policy denied DROPPED`). Die Diagnose der
eingebauten VPC CNI Network Policy hat keine solche Per-Flow-Verdict-Karte - dort gibt es
nur Logs des Agenten `aws-network-policy-agent` und Metriken (Chapter 8).

## Aufgabe 8. Vergleich: VPC CNI NP gegenüber Cilium in diesem Lab

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/comparison.txt <<'EOF'
Was die eingebaute VPC CNI NetworkPolicy kann, was Cilium hinzugefügt hat, was es kostet:

1. VPC CNI NetworkPolicy deckt nur L3/L4 ab. Cilium hat in diesem Lab eine L7-Regel nach
   HTTP-Methode hinzugefügt: GET erlaubt (200), POST vom Envoy-Proxy mit Code 403
   abgelehnt.

2. VPC CNI NP hat keine Richtlinien nach DNS-Namen. Cilium hat eine CiliumNetworkPolicy mit
   toFQDNs hinzugefügt - Egress ist nur zu aws.amazon.com erlaubt, example.com wird
   verworfen (HTTP_CODE=000).

3. Die Diagnose der eingebauten VPC CNI NP beschränkt sich auf Agent-Logs und Metriken.
   Cilium hat Hubble gebracht: eine Flow-Karte mit Per-Flow-Verdict
   (FORWARDED/DROPPED) via hubble observe.

4. Der Preis dafür: ein eigener Helm-Release von Cilium mit eigenen Upgrades, ein zweites
   CRD-Modell für das Team, eine zusätzliche Schicht im Datapath, und die Tatsache, dass
   Pods außerhalb des cilium-demo-Pools (zum Beispiel coredns auf Fargate) außerhalb des
   Cilium-Datapath bleiben und in Richtlinien nur als reserved:world sichtbar sind - Regeln
   nach Label gelten für sie nicht.

5. Ein vollständiger Ersatz von VPC CNI (wenn aws-node entfernt wird und Cilium selbst zum
   IPAM wird) gehört nicht zum Umfang dieses Labs: das Umschalten des CNI auf einem
   laufenden Cluster ist eine blue/green-Operation über neue Nodes, kein Umschalten eines
   Flags im laufenden Betrieb (chapter 8, Abschnitt 8.8). Hier wurde nur die sichere
   Option - CNI Chaining - geübt.
EOF
cat /var/work/tests/artifacts/8/comparison.txt
```

## Schnelle Prüfung

```bash
check_result
```

## Fallstricke in diesem Lab

Alle vier Punkte wurden auf einem Live-Prüfstand verifiziert.

1. `cilium-operator` bringt das Cluster-DNS zu Fall. Standardmäßig gilt
   `operator.unmanagedPodWatcher.restart=true`: der Operator löscht alle 15 Sekunden Pods
   ohne `CiliumEndpoint`. `coredns` auf Fargate wird das niemals werden, daher werden seine
   Pods im Kreis gelöscht, für jeden entsteht eine neue Fargate-Mikro-VM, und das DNS im
   Cluster kommt und geht. Das Symptom auf Pod-Seite: `nslookup` liefert
   `connection timed out; no servers could be reached`. Wer genau die Pods löscht, sieht
   man im Audit-Log der Control Plane: in den Einträgen `verb: delete` auf `coredns`-Pods
   stehen `user.username = system:serviceaccount:kube-system:cilium-operator` und
   `userAgent = cilium-operator-generic/1.20.0`. Behoben wird das mit dem Flag
   `operator.unmanagedPodWatcher.restart=false` (in `cilium-config` erscheint
   `unmanaged-pod-watcher-interval: "0"`).

2. Das Fargate-Profil kennt kein `nodeSelector`. Deckt das Profil den gesamten Namespace
   `kube-system` ab (`selectors = [{ namespace = "kube-system" }]`), markiert der
   Fargate-Webhook mit seinem Profil JEDEN Pod, den du diesem Namespace später hinzufügst,
   einschließlich `cilium-operator`. Danach wird der Pod nur noch vom
   `fargate-scheduler` geplant, der weder `hostNetwork` noch `nodeSelector` kennt und
   niemals auf den regulären Scheduler zurückfällt. Symptome: `Pod not supported on
   Fargate: fields not supported: HostNetwork, port contains HostIP or HostPort`, und nach
   `operator.hostNetwork=false` - `MatchNodeSelector failed: Fargate profile kube-system
   cannot satisfy pod's node selector/affinity requirements`. Deshalb ist das Profil in
   diesem Lab durch den Label-Selektor `eks.amazonaws.com/component: coredns` eingeschränkt
   (siehe `eks_fargate_system/terragrunt.hcl`).

3. Das Fargate-Profil wurde neu erstellt - starte die Pods neu, die es aufnehmen soll. Die
   Pod-Mutation erfolgt nur im Moment der Pod-Erstellung, daher bleibt ein
   `karpenter`-Pod, der erstellt wurde, bevor das neue Profil `ACTIVE` wurde, für immer in
   `Pending` mit `0/N nodes are available: N node(s) had untolerated taint(s)`. Behoben
   wird das mit `kubectl delete pod` für diesen Pod.

4. `cilium-envoy`-Pods hängen in `Pending`, wenn nur der oberste `nodeSelector` gesetzt
   wird. Das DaemonSet `cilium-envoy` hat seine eigene Sektion `envoy.nodeSelector` /
   `envoy.tolerations`; ohne sie zielt es auf alle Linux-Nodes, und `cilium status` zeigt
   `Envoy DaemonSet: 1 errors`.
