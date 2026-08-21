[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 124 - Referenzlösung (HPA, KEDA, Prometheus)

Alle Befehle laufen auf der Worker-Maschine per SSH. kubectl und helm sind bereits
konfiguriert (die kubeconfig wird beim Booten der Maschine per `aws eks
update-kubeconfig` zusammengestellt).

## Aufgabe 1. Namespace `eks-124`

```bash
kubectl create namespace eks-124
```

## Aufgabe 2. kube-prometheus-stack im Namespace `monitoring`

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.enabled=false \
  --set alertmanager.enabled=false \
  --set prometheus.prometheusSpec.resources.requests.cpu=200m \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi
```

Diese drei Flags sind nicht kosmetisch. Die Lab braucht weder Grafana noch Alertmanager,
und Grafana ist der schwerste Pod im Chart (etwa 325 MiB auf dem Testaufbau). Explizite
`requests` überführen Prometheus von `BestEffort` nach `Burstable`: Sowohl der Scheduler
als auch Karpenter, das die Knotengröße anhand der Summe der `requests` bemisst, können
seinen Bedarf sehen. Ohne das landet der Monitoring-Stack auf der günstigsten Instanz, und
kubelet vertreibt Prometheus bei Speicherdruck - eine ausführliche Erklärung steht im
README der Lab.

Wir warten, bis die Pods bereit sind:

```bash
kubectl get pods -n monitoring -w
```

Wir warten, bis alle Pods `Running` und `1/1` (oder `2/2`) Ready erreichen - das dauert
üblicherweise 2-3 Minuten. Wir kontrollieren den Service, auf den KEDA schauen wird, und
die QoS-Klasse des Pods:

```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 \
  -o jsonpath='{.status.qosClass}{"\n"}'
```

Die erwartete Ausgabe des zweiten Befehls ist `Burstable`.

## Aufgabe 3. KEDA im Namespace `keda`

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda --namespace keda --create-namespace
```

Wir kontrollieren, dass der Operator und der Metrics-Apiserver oben sind:

```bash
kubectl get pods -n keda
```

Erwartetes Ergebnis: Pods mit Namen wie `keda-operator-...` und
`keda-operator-metrics-apiserver-...` im Zustand `Running`.

## Aufgabe 4. Deployment `demo-app`

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: eks-124
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        resources:
          requests:
            cpu: "200m"
            memory: "128Mi"
EOF

kubectl rollout status deployment/demo-app -n eks-124
```

## Aufgabe 5. ScaledObject mit dem Scaler `prometheus`

Die cAdvisor-Metrik `container_cpu_usage_seconds_total` wird von kube-prometheus-stack von
jedem Pod von Haus aus erfasst, ohne dass ein ServiceMonitor nötig wäre. Wir berechnen die
Gesamt-CPU-Nutzung der Pods des Last-GENERATORS aus Aufgabe 6, nicht von `demo-app` selbst:
Die Anwendung skaliert anhand fremder Last, und ein gewöhnliches CPU-basiertes HPA kann das
nicht - genau dafür gibt es externe Metriken.

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: demo-app
  namespace: eks-124
spec:
  scaleTargetRef:
    name: demo-app
  minReplicaCount: 1
  maxReplicaCount: 5
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://kube-prometheus-stack-prometheus.monitoring.svc:9090
      query: sum(rate(container_cpu_usage_seconds_total{namespace="eks-124", pod=~"stress-generator.*"}[1m]))
      threshold: "0.1"
EOF
```

Man kann direkt aus dem Cluster kontrollieren, ob die Abfrage überhaupt etwas zurückgibt
(solange es noch keinen Generator gibt, ist die Antwort leer, und das ist normal - KEDA
meldet HPA in diesem Fall null):

```bash
kubectl run promq --rm -i --restart=Never -n default --image=curlimages/curl -- \
  -sG --data-urlencode \
  'query=sum(rate(container_cpu_usage_seconds_total{namespace="eks-124",pod=~"stress-generator.*"}[1m]))' \
  http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/query
```

Wir kontrollieren, dass KEDA das ScaledObject unter Kontrolle genommen und das HPA erstellt hat:

```bash
kubectl get scaledobject demo-app -n eks-124
kubectl get hpa -A | grep keda-hpa
kubectl get hpa keda-hpa-demo-app -n eks-124
```

Das HPA heißt `keda-hpa-demo-app` - das ist der Beweis, dass KEDA HPA nicht ersetzt,
sondern unter der Haube ein gewöhnliches `HorizontalPodAutoscaler` erstellt und führt.

## Aufgabe 6. Lasttest: Hochskalieren

Zuerst halten wir den Zustand vor der Last fest:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_before.txt
cat /var/work/tests/artifacts/6/hpa_before.txt
```

Wir erstellen den Last-Generator. Er hat sein eigenes Label (`app=stress-generator`) - die
PromQL-Abfrage aus Aufgabe 5 wählt Pods anhand des NAMENS, nicht anhand des Labels, daher
ist es unnötig und schädlich, den Generator in den Selektor von `demo-app` zu mischen: zwei
Deployments mit überlappenden Selektoren sind ein Anti-Pattern. `limits.cpu` ist
zwingend, sonst entziehen die vier CPU-Worker kubelet die CPU und der Knoten wird
`NotReady`. `nodeSelector` ist nötig, weil `polinux/stress` nur für `amd64` gebaut ist,
während der NodePool dieser Lab auch `arm64` erlaubt:

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-generator
  namespace: eks-124
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stress-generator
  template:
    metadata:
      labels:
        app: stress-generator
    spec:
      nodeSelector:
        kubernetes.io/arch: amd64
      containers:
      - name: stress
        image: polinux/stress
        command: ["stress"]
        args: ["--cpu", "2"]
        resources:
          requests:
            cpu: "200m"
          limits:
            cpu: "500m"
EOF
```

Wir beobachten, wie die Metrik und die Replikatanzahl wachsen:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

Wir warten 1-2 Minuten (KEDA fragt Prometheus ab, HPA berechnet die Replikate, Karpenter
fügt bei Bedarf einen Knoten hinzu). Auf dem Testaufbau sah das so aus:

```
06:36:41 replicas=1 0/100m (avg)
06:37:04 replicas=1 1251m/100m (avg)
06:37:26 replicas=4 382m/100m (avg)
```

Sobald `REPLICAS` größer als `1` wird, speichern wir:

```bash
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_after.txt
cat /var/work/tests/artifacts/6/hpa_after.txt
```

## Aufgabe 7. Entfernen der Last: Herunterskalieren

```bash
kubectl delete deployment stress-generator -n eks-124
```

Die Pods des Generators verschwinden, ihre Serien sind aus Prometheus weg, KEDA meldet dem
HPA null. Der Wert von `TARGETS` fällt in etwa 30 Sekunden auf null, aber die
Replikatanzahl bleibt bestehen: `stabilizationWindowSeconds` für scaleDown am HPA beträgt
standardmäßig 300 Sekunden. Eine Messung vom Testaufbau - Metrik null um 06:40:07,
Replikate `5 -> 2 -> 1` um 06:44:40 und 06:45:07:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

Sobald `REPLICAS` wieder `1` erreicht, speichern wir das Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/7/hpa_after_cooldown.txt
cat /var/work/tests/artifacts/7/hpa_after_cooldown.txt
```

## Aufgabe 8. Ein normales HPA im Vergleich zu einem von KEDA erstellten HPA

```bash
kubectl get hpa -A
```

In der Ausgabe sieht das HPA `keda-hpa-demo-app` spaltenweise identisch zu einem
normalen HPA aus - dieselben `TARGETS`, `MINPODS`, `MAXPODS`, `REPLICAS`. Der einzige
Unterschied ist der Name (Präfix `keda-hpa-`) und wer es steuert: Ein Ingenieur erstellt
und bearbeitet ein normales HPA direkt über ein `HorizontalPodAutoscaler`-Manifest,
während `keda-hpa-demo-app` vom KEDA-Operator anhand der `ScaledObject`-Ressource
erstellt und gesteuert wird: Löschen Sie das
`ScaledObject`, und KEDA löscht dieses HPA gleich mit.

Wir speichern die Erklärung im Artefakt:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/hpa_compare.txt <<'EOF'
In kubectl get hpa -A sehen ein normales HPA und das HPA keda-hpa-demo-app spaltenweise
identisch aus: TARGETS/MINPODS/MAXPODS/REPLICAS - der einzige Unterschied liegt im Namen
und in der Herkunft des Objekts.

KEDA ersetzt HPA nicht: der KEDA-Operator beobachtet das ScaledObject und erstellt und
steuert (control) selbst ein gewöhnliches HorizontalPodAutoscaler mit dem Namen
keda-hpa-<Name des ScaledObject>, während der KEDA-Metrics-Adapter ihm den Metrikwert
über external.metrics.k8s.io liefert. Die Replikate berechnet weiterhin derselbe
HPA-Mechanismus wie immer.
EOF
cat /var/work/tests/artifacts/8/hpa_compare.txt
```

## Schnellkontrolle

```bash
check_result
```
