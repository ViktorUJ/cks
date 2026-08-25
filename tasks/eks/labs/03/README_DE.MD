[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)


# Labor: Anwendungsautoskalierung mit KEDA und Prometheus

## Beschreibung

Dieses Labor zeigt, wie eine Webanwendung in Amazon EKS mithilfe von **KEDA** (Kubernetes Event-Driven Autoscaling) auf Grundlage von **Prometheus**-Metriken automatisch skaliert wird. Die Anwendung exportiert eigene Anfrage-Metriken, Prometheus sammelt sie, und KEDA skaliert das Deployment je nach tatsächlicher Anzahl der Anfragen pro Sekunde (RPS) hoch und herunter.

Der Cluster ist bereits mit **Karpenter** und zwei dedizierten NodePools vorbereitet:
- `monitoring` — für den Monitoring-Stack (Prometheus, KEDA, metrics-server)
- `default` — für die Testanwendung

**Was Sie lernen werden:**
- Wie der offizielle Prometheus Operator (kube-prometheus-stack) über Helm installiert wird
- Wie Workloads mit nodeAffinity und tolerations an dedizierte Nodes gebunden werden
- Wie Prometheus über einen LoadBalancer für schnellen Zugriff veröffentlicht wird
- Wie benutzerdefinierte Anwendungsmetriken über ServiceMonitor gesammelt werden
- Wie KEDA installiert und ein ScaledObject auf Grundlage einer Prometheus-Abfrage konfiguriert wird
- Wie Last erzeugt und die automatische Hoch-/Herunterskalierung beobachtet wird
- Wie Cloud-Ressourcen (LoadBalancer, Karpenter-Nodes) korrekt entfernt werden

## Inhalt
- [Umgebung vorbereiten](#umgebung-vorbereiten)
  - [Labor starten](#labor-starten)
  - [Erstellte Ressourcen](#erstellte-ressourcen)
  - [Voraussetzungen](#voraussetzungen)
- [NodePools anzeigen](#nodepools-anzeigen)
- [Monitoring-Stack installieren](#monitoring-stack-installieren)
  - [Prometheus Operator und metrics-server](#prometheus-operator-und-metrics-server)
  - [Installation prüfen](#installation-prüfen)
- [Anwendung bereitstellen](#anwendung-bereitstellen)
- [Anwendungsmetriken sammeln](#anwendungsmetriken-sammeln)
  - [ServiceMonitor erstellen](#servicemonitor-erstellen)
  - [Target prüfen](#target-prüfen)
  - [Metriken in Prometheus prüfen](#metriken-in-prometheus-prüfen)
- [KEDA installieren](#keda-installieren)
- [Autoskalierung konfigurieren](#autoskalierung-konfigurieren)
  - [Verfügbare Anwendungsmetriken](#verfügbare-anwendungsmetriken)
  - [ScaledObject erstellen](#scaledobject-erstellen)
- [Last erzeugen und Skalierung beobachten](#last-erzeugen-und-skalierung-beobachten)
- [Ressourcen bereinigen](#ressourcen-bereinigen)
- [Fazit](#fazit)


## Umgebung vorbereiten

### Labor starten
[Plattform über Docker starten](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

Führen Sie zum Starten des Labors folgenden Befehl aus:

```bash
TASK=03 make run_eks_task
```

**Was beim Ausführen dieses Befehls geschieht:**
- Terraform/Terragrunt stellt automatisch die gesamte erforderliche Infrastruktur in AWS bereit
- Der Vorgang dauert etwa 15-20 Minuten
- Die Befehlsausgabe zeigt wichtige Informationen an (SSH-Verbindung, Ressourcennamen)

### Erstellte Ressourcen

Beim Ausführen des Befehls wird folgende AWS-Infrastruktur bereitgestellt:

#### Netzwerkinfrastruktur (VPC)
- **VPC** mit dem CIDR-Block `10.10.0.0/16` in der Region `eu-central-1`
- **Öffentliche Subnetze** für Ressourcen mit Internetzugang (`eks-AZ-1`, `eks-AZ-2`)
- **Private Subnetze** für EKS-Nodes und RDS
- **NAT Gateway** für ausgehenden Internetverkehr aus privaten Subnetzen

#### EKS-Cluster
- **EKS Control Plane** in Version `1.35`
- **Fargate-Profil** für System-Pods (`kube-system`, `karpenter`) — beachten Sie: CoreDNS läuft auf Fargate
- **Karpenter** in Version `1.8.1` (Autoskalierungs-Controller)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Vorkonfigurierte Karpenter-NodePools
- **`default`** — für Anwendungs-Workloads (konsolidiert leere Nodes nach 30s)
- **`monitoring`** — für den Monitoring-Stack reserviert, mit taint `dedicated=monitoring:NoSchedule` und label `work_type=monitoring` (konsolidiert nach 300s)

#### Hauptkonfigurationsdatei

Alle Infrastrukturparameter sind in der Datei `tasks/eks/labs/03/env.hcl` festgelegt. Um die Konfiguration zu ändern, bearbeiten Sie die entsprechenden Parameter in dieser Datei.

### Voraussetzungen

Stellen Sie sicher, dass Sie Folgendes haben:
- **AWS CLI** mit den entsprechenden Zugriffsrechten
- Erhöhte Node-Limits in der Region `eu-central-1` (falls erforderlich)
- SSH-Zugriff auf einen Worker-Node (die Verbindungszeichenfolge finden Sie in der Ausgabe von `make run_eks_task`)
- Auf dem Worker-Node verfügbares `kubectl`, `helm` und `jq`


## NodePools anzeigen

Zwei NodePools sind bereits vorbereitet. Prüfen wir sie:

```bash
kubectl get nodepools.karpenter.sh
```

**Erwartetes Ergebnis:**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — für Prometheus, KEDA und metrics-server
- **`default`** — für die Testanwendung

Sehen wir uns den NodePool `monitoring` genauer an:

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**Wichtige Teile der Spezifikation:**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # wird in nodeAffinity verwendet
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # hier werden nur Pods mit passender toleration platziert
```

**Was das bedeutet:** Monitoring-Pods müssen sowohl `nodeAffinity` auf `work_type=monitoring` als auch eine `toleration` für `dedicated=monitoring:NoSchedule` haben. Das stellt sicher, dass der Monitoring-Stack auf seinen eigenen Nodes läuft und nichts Unnötiges dort landet.


## Monitoring-Stack installieren

### Prometheus Operator und metrics-server

Wir installieren **kube-prometheus-stack** (den offiziellen Prometheus Operator) und **metrics-server** über Helm. Grafana ist deaktiviert. Alle Komponenten werden über `nodeAffinity` + `tolerations` an den NodePool `monitoring` gebunden.

> **Sicherheitshinweis:** Der untenstehende Prometheus-Service wird über einen öffentlichen LoadBalancer **ohne Authentifizierung** veröffentlicht. Dies dient nur der Bequemlichkeit im Labor. In Produktion muss Prometheus geschützt werden (Authentifizierung / OAuth2 proxy, IP-Einschränkung über Security Groups oder NetworkPolicy, Ingress mit TLS).

```bash
# Helm-Repositories hinzufügen
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Values-Datei für Prometheus erstellen
cat <<'EOF' > prometheus-values.yaml
# ACHTUNG: Der Prometheus-LoadBalancer ist ohne Authentifizierung geöffnet.
# Dies ist nur für das Labor. Schützen Sie Prometheus in Produktion durch
# Authentifizierung, IP-Einschränkung (Security Groups / NetworkPolicy) und TLS.

grafana:
  enabled: false

kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

prometheus:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    loadBalancerSourceRanges:
      - "0.0.0.0/0"
  prometheusSpec:
    serviceMonitorSelectorNilUsesHelmValues: false
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelector: {}
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

prometheusOperator:
  admissionWebhooks:
    patch:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: work_type
                    operator: In
                    values:
                      - monitoring
      tolerations:
        - key: dedicated
          value: monitoring
          effect: NoSchedule
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

alertmanager:
  alertmanagerSpec:
    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: work_type
                  operator: In
                  values:
                    - monitoring
    tolerations:
      - key: dedicated
        value: monitoring
        effect: NoSchedule

kube-state-metrics:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: work_type
                operator: In
                values:
                  - monitoring
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule

prometheus-node-exporter:
  tolerations:
    - key: dedicated
      value: monitoring
      effect: NoSchedule
EOF

# Values-Datei für metrics-server erstellen
cat <<'EOF' > metrics-server-values.yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule
EOF

# Prometheus Operator installieren
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# metrics-server installieren
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**Erläuterungen zu den Values:**
- `serviceMonitorSelectorNilUsesHelmValues: false` + leere Selektoren ermöglichen Prometheus, ServiceMonitor aus **allen** Namespaces zu übernehmen (dies wird benötigt, um später Anwendungsmetriken zu sammeln).
- Jede Komponente deklariert `nodeAffinity` (`work_type=monitoring`) und wird daher **nur** auf Monitoring-Nodes geplant. Ein `nodeSelector` allein reicht nicht aus — affinity garantiert die Platzierung.
- `node-exporter` erhält nur eine toleration (er muss als DaemonSet auf jedem Node laufen).

### Installation prüfen

```bash
# Alle Monitoring-Pods müssen auf Monitoring-Nodes Running sein
kubectl get pods -n monitoring -o wide

# Monitoring-Nodes müssen hochgefahren werden
kubectl get nodes -l work_type=monitoring

# metrics-server muss laufen
kubectl top nodes

# Adresse des Prometheus-LoadBalancers abrufen (Prometheus-UI auf Port 9090)
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

Öffnen Sie `http://<LB-ADDRESS>:9090` im Browser, um auf die Prometheus-UI zuzugreifen.


## Anwendung bereitstellen

Stellen Sie die Testanwendung (`ping_pong`) bereit. Der Service veröffentlicht zwei Ports: `http` (80 → 8080) und `metrics` (9090 → 9090).

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

Prüfen Sie, dass die Anwendung gestartet ist:

```bash
kubectl get po -n team-19
```

**Erwartetes Ergebnis:**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

Prüfen Sie NodeClaim — es sollte ein separater Node für Monitoring und ein separater für die Anwendung vorhanden sein:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Erwartetes Ergebnis:**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## Anwendungsmetriken sammeln

### ServiceMonitor erstellen

Die Anwendung exportiert Prometheus-Metriken auf Port `9090` unter dem Pfad `/metrics`. Der Port `metrics` ist bereits im Service der Anwendung definiert, daher wird nur ein ServiceMonitor benötigt. Das Label `release: prometheus` ermöglicht dem Prometheus Operator, ihn zu übernehmen.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: team19
  namespace: team-19
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: team19
  endpoints:
  - port: metrics
    interval: 15s
    path: /metrics
EOF
```

### Target prüfen

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Target muss vorhanden und fehlerfrei sein (health: up)
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### Metriken in Prometheus prüfen

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Metrik requests_total prüfen
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

Wenn das Ergebnis leer ist (`[]`), wurde der ServiceMonitor noch nicht übernommen. Warten Sie kurz und wiederholen Sie den Vorgang, oder prüfen Sie oben den Zustand des Targets.

Sie können auch `http://<PROM_URL>:9090` im Browser öffnen und `requests_total` in das Feld Expression eingeben.

> **Tipp:** Der Metrikwert wird als `"value": [<timestamp>, "<Wert>"]` zurückgegeben. Die erste Zahl ist die Scrape-Zeit, die zweite (Zeichenfolge) der eigentliche Wert. Er ist `0`, solange kein Traffic zur Anwendung geht.


## KEDA installieren

KEDA läuft auf denselben Nodes wie Prometheus (NodePool `monitoring`). Das KEDA-Helm-Chart wendet die `tolerations` und `affinity` der obersten Ebene auf **alle** seine Komponenten an (operator, metrics apiserver, webhooks).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# Globale tolerations und affinity für alle KEDA-Komponenten
tolerations:
  - key: dedicated
    value: monitoring
    effect: NoSchedule

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: work_type
              operator: In
              values:
                - monitoring
EOF

helm install keda kedacore/keda \
  --namespace monitoring \
  -f keda-values.yaml
```

### KEDA prüfen

```bash
# KEDA-Pods müssen auf Monitoring-Nodes Running sein
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# KEDA-CRDs müssen installiert sein
kubectl get crd | grep keda
```

> **Hinweis:** Der KEDA-`metrics-apiserver` ist eine interne KEDA-Komponente (er stellt externe Metriken für Kubernetes HPA bereit). Dies ist **nicht** dasselbe wie der zuvor installierte clusterweite `metrics-server` — beide werden benötigt.


## Autoskalierung konfigurieren

### Verfügbare Anwendungsmetriken

Die Anwendung `ping_pong` exportiert folgende Prometheus-Metriken (Port 9090, Pfad `/metrics`):

| Metrik | Typ | Beschreibung |
|---------|-----|--------------|
| `requests_total` | Counter | Gesamtzahl der Anfragen |
| `requests_per_second` | Gauge | Momentaner RPS (rauschbehaftet, wird bei Inaktivität nicht auf 0 zurückgesetzt) |
| `requests_per_minute` | Gauge | Momentaner RPM |
| `goroutines` | Gauge | Aktuelle Anzahl der Goroutinen |

Für die Skalierung verwenden wir **`rate(requests_total[1m])`** und nicht den rohen Gauge `requests_per_second`. `rate()` auf Grundlage eines Zählers liefert einen echten geglätteten RPS, der mit der Last linear steigt und ehrlich auf 0 fällt, wenn der Traffic endet — dadurch lässt sich der Schwellenwert leicht wählen.

### ScaledObject erstellen

Regel: Replikate = `ceil(sum(rate(requests_total[1m])) / threshold)`. Über `behavior` ist eine schnelle Verringerung konfiguriert, damit Pods nach einem Lastrückgang schnell entfernt werden.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: team19-scaledobject
  namespace: team-19
spec:
  scaleTargetRef:
    name: team19
  minReplicaCount: 1
  maxReplicaCount: 10
  pollingInterval: 10
  cooldownPeriod: 10
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleDown:
          # Schnelle Verringerung: Stabilisierungsfenster 10s, bis zu 100% der Pods können entfernt werden
          stabilizationWindowSeconds: 10
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
        scaleUp:
          stabilizationWindowSeconds: 0
          policies:
          - type: Percent
            value: 100
            periodSeconds: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-kube-prometheus-prometheus.monitoring.svc.cluster.local:9090
      # rate(requests_total[1m]) -> echter RPS aus dem Zähler; Summe über alle Pods.
      # Replikate = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**Erläuterungen:**
- `threshold` — der Ziel-RPS **pro Pod**, den HPA aufrechtzuerhalten versucht.
- `activationThreshold: 3` bedeutet, dass KEDA eine Replik hält, solange der Gesamt-RPS 3 nicht übersteigt, wodurch Schwankungen bei Inaktivität vermieden werden.
- Die `query` verwendet `sum(...)` (Gesamt-RPS, unabhängig von der Replikatanzahl), daher ist die gewünschte Anzahl der Replikate stabil. Die Verwendung von `avg(...)` würde hier bei der Hinzufügung von Pods zu Oszillationen führen.

Prüfen Sie das ScaledObject und den von ihm erstellten HPA:

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## Last erzeugen und Skalierung beobachten

Starten Sie einen Pod, der Last auf dem Service der Anwendung erzeugt. Die innere Schleife sendet N Anfragen, der äußere `sleep 1` bestimmt das Tempo — daher entspricht die Zahl in `seq 1 N` ungefähr dem Ziel-RPS.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: traffic-generator
  namespace: team-19
spec:
  containers:
  - name: loader
    image: busybox
    command:
    - /bin/sh
    - -c
    - |
      echo "Starting traffic generation..."
      while true; do
        for i in $(seq 1 50); do
          wget -q -O /dev/null http://team19.team-19.svc.cluster.local:80/ &
        done
        sleep 1
      done
EOF
```

### Skalierung beobachten

Ein einzelnes `watch` zeigt gleichzeitig Pods, HPA und RPS pro Pod aus Prometheus. Die PromQL-Abfrage wird URL-kodiert (`--data-urlencode`), da die Zeichen `{`, `}` und `=` andernfalls den Parser stören.

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**Was Sie sehen sollten:** Mit zunehmender Last strebt die Anzahl der Pods gegen `ceil(gesamt_rps / threshold)`. Die HPA-Spalte `TARGETS` (RPS pro Pod) entspricht `rps per pod`, das von watch ausgegeben wird.

> **Tipp zur Auswahl:** Pods ≈ (Zahl in `seq 1 N`) / threshold. Mit `seq 1 50` und `threshold: 10` erhalten Sie etwa 5 Pods. Erhöhen Sie die Zahl, um mehr Pods zu erhalten.

### Last anhalten

```bash
kubectl delete pod traffic-generator -n team-19
```

Nach dem Stoppen des Traffics fällt `rate(requests_total[1m])` auf 0. Innerhalb von `cooldownPeriod` (10s) plus dem Stabilisierungsfenster für die Verringerung (10s) skaliert KEDA zurück auf `minReplicaCount: 1`.


## Ressourcen bereinigen

### Anwendung entfernen

```bash
# ScaledObject entfernen (KEDA verwaltet den HPA nicht mehr)
kubectl delete scaledobject team19-scaledobject -n team-19

# Traffic-Generator entfernen (falls noch ausgeführt)
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# ServiceMonitor entfernen
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# Die Anwendung selbst entfernen (deployment, service, namespace)
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### Prometheus entfernen (wichtig: entfernt den LoadBalancer)

Durch das Entfernen des Helm-Releases wird der Service vom Typ LoadBalancer entfernt und AWS gibt den ELB frei.

```bash
# prometheus entfernen (dies entfernt den Service LoadBalancer -> AWS ELB)
helm uninstall prometheus -n monitoring

# metrics-server und keda entfernen
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

Prüfen Sie, dass der LoadBalancer (ELB) tatsächlich entfernt wurde:

```bash
# Der Service prometheus darf nicht existieren
kubectl get svc -n monitoring | grep prometheus

# In AWS bestätigen, dass der ELB entfernt wurde
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

Wenn der Service aus irgendeinem Grund bestehen geblieben ist und das Entfernen des ELB blockiert, entfernen Sie ihn manuell:

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

Entfernen Sie anschließend den Namespace:

```bash
kubectl delete namespace monitoring
```

> **Wichtig:** Entfernen Sie Services vom Typ LoadBalancer immer **vor** dem Entfernen von Nodes oder des Clusters.
> Wenn Sie zuerst die Nodes/den Cluster entfernen, kann AWS ELB als orphaned-Ressource "hängen bleiben",
> und muss dann manuell über die Konsole oder CLI entfernt werden.

### Prüfen, dass Karpenter alle Nodes entfernt hat

Nach dem Entfernen aller Workloads werden die Nodes `default` und `monitoring` leer, und Karpenter sollte sie konsolidieren (entfernen).

```bash
# Beobachten, wie die Anzahl der nodeclaims auf null sinkt
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter entfernt leere Nodes gemäß `consolidateAfter` jedes NodePool
(`default` = 30s, `monitoring` = 300s), daher werden Monitoring-Nodes später entfernt.

Warten Sie, bis beide Befehle ein leeres Ergebnis zurückgeben:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

Wenn ein Node nicht entfernt wird — prüfen Sie Pods, die die Konsolidierung verhindern (z. B. Pods ohne Controller oder mit `karpenter.sh/do-not-disrupt`):

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<имя-ноды>
```

### Infrastruktur entfernen

Erst nachdem Karpenter alle Nodes entfernt hat, entfernen Sie die Infrastruktur des Labors:

```bash
TASK=03 make delete_eks_task
```

Geben Sie zur Bestätigung `y` ein. Der Löschvorgang dauert etwa 10-15 Minuten.

> Das Entfernen der Infrastruktur, bevor Karpenter seine Nodes entfernt hat, kann orphaned EC2-Instanzen zurücklassen.


## Fazit

Herzlichen Glückwunsch! Sie haben ein ereignisgesteuertes Autoskalierungssystem auf EKS erstellt.

**Was Sie getan haben:**

1. **Monitoring-Stack** — den offiziellen Prometheus Operator und metrics-server installiert und über nodeAffinity und tolerations an dedizierte Nodes gebunden
2. **Veröffentlichung** — Prometheus über LoadBalancer für schnellen Zugriff veröffentlicht (nur für das Labor, ohne Authentifizierung)
3. **Benutzerdefinierte Metriken** — eigene Anfragemetriken der Anwendung über ServiceMonitor gesammelt
4. **KEDA** — KEDA installiert und ein ScaledObject auf Grundlage einer Prometheus-Abfrage konfiguriert
5. **Autoskalierung** — die Anwendung anhand des tatsächlichen RPS über `rate(requests_total[1m])` mit schneller Verringerung skaliert
6. **Bereinigung** — den LoadBalancer korrekt entfernt und Karpenter die Nodes vor dem Entfernen der Infrastruktur freigeben lassen

**Wichtigste Erkenntnisse:**

- Verwenden Sie `rate()` auf Grundlage eines Zählers für eine stabile, vorhersehbare Autoskalierung anstelle von rauschbehafteten momentanen Gauges
- Verwenden Sie `sum(...)` (nicht `avg(...)`) in der Skalierer-Abfrage, damit die gewünschte Replikatanzahl bei der Hinzufügung von Pods nicht oszilliert
- Binden Sie Infrastruktur-Workloads über nodeAffinity **und** tolerations an dedizierte Nodes
- Entfernen Sie Services vom Typ LoadBalancer immer vor dem Entfernen des Clusters, um orphaned ELBs zu vermeiden

**Zusätzliche Ressourcen:**
- [KEDA-Dokumentation](https://keda.sh/docs/)
- [Prometheus-Scaler in KEDA](https://keda.sh/docs/latest/scalers/prometheus/)
- [kube-prometheus-stack-Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Karpenter-Dokumentation](https://karpenter.sh/docs/)
