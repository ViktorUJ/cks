[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 114 - Referenzlösung (Observability: Container Insights und Managed Prometheus)

Alle Befehle werden auf der Worker-Maschine (worker) per SSH ausgeführt. kubectl und helm sind
bereits konfiguriert. Terraform hat bereits den AMP workspace erstellt, dessen Alias in
`~/lab114_hints.txt` gespeichert ist.

```bash
cat ~/lab114_hints.txt
```

## Aufgabe 1. Namespace `eks-114`

```bash
kubectl create namespace eks-114
```

## Aufgabe 2. Symptom: es gibt überhaupt keine Metriken

```bash
mkdir -p /var/work/tests/artifacts/2
{
  echo "=== kubectl top nodes ==="
  kubectl top nodes
  echo "=== kubectl top pods -A ==="
  kubectl top pods -A
} > /var/work/tests/artifacts/2/kubectl_top_before.txt 2>&1

cat /var/work/tests/artifacts/2/kubectl_top_before.txt
```

Beide Befehle schlagen mit `error: Metrics API not available` fehl - die Metrics API
(`metrics.k8s.io`) ist nicht registriert, weil metrics-server noch nicht installiert ist.

## Aufgabe 3. Basisschicht: der Addon metrics-server

```bash
CLUSTER_NAME=$(kubectl config current-context | sed 's|.*/||')

aws eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" --addon-name metrics-server
aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
  --query 'addon.status'
```

Wir warten, bis die Metrics API beginnt, echte Zahlen zu liefern (dauert normalerweise ein
bis zwei Minuten, nachdem der Addon `ACTIVE` geworden ist):

```bash
for i in $(seq 1 24); do
  out=$(kubectl top nodes 2>&1)
  if [[ "$out" != *"not available"* ]]; then
    break
  fi
  sleep 10
done

mkdir -p /var/work/tests/artifacts/3
kubectl top nodes > /var/work/tests/artifacts/3/kubectl_top_after.txt
cat /var/work/tests/artifacts/3/kubectl_top_after.txt
```

## Aufgabe 4. Container Insights: der Addon amazon-cloudwatch-observability

Der Addon benötigt Rechte zum Veröffentlichen in CloudWatch. EKS Pod Identity verwendet nicht
den OIDC-Provider des Clusters, daher vertraut die trust policy der Rolle direkt dem Dienst
`pods.eks.amazonaws.com`:

```bash
ROLE_NAME="eks-task114-test-cw-agent"

cat > /tmp/trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "pods.eks.amazonaws.com" },
      "Action": ["sts:AssumeRole", "sts:TagSession"]
    }
  ]
}
EOF

aws iam create-role --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust.json

aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
echo "$ROLE_ARN"
```

Wir installieren den Addon mit einer Pod Identity association auf dieses ServiceAccount:

```bash
aws eks create-addon --cluster-name "$CLUSTER_NAME" \
  --addon-name amazon-cloudwatch-observability \
  --pod-identity-associations serviceAccount=cloudwatch-agent,roleArn="$ROLE_ARN"

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" \
  --addon-name amazon-cloudwatch-observability

for i in $(seq 1 30); do
  running=$(kubectl get pods -n amazon-cloudwatch \
    -l app.kubernetes.io/name=cloudwatch-agent \
    -o jsonpath='{.items[*].status.phase}')
  [[ "$running" == *Running* ]] && break
  sleep 10
done

mkdir -p /var/work/tests/artifacts/4
kubectl get pods -n amazon-cloudwatch > /var/work/tests/artifacts/4/cloudwatch_agent_pods.txt
cat /var/work/tests/artifacts/4/cloudwatch_agent_pods.txt
```

## Aufgabe 5. kube-prometheus-stack: echtes Sammeln von Anwendungsmetriken

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=300s
```

`serviceMonitorSelectorNilUsesHelmValues=false` ist wichtig: ohne diesen Wert sieht Prometheus
nur den ServiceMonitor aus seinem eigenen Helm-Release und ignoriert `ping-app` aus einem
anderen namespace.

Wir rollen die Anwendung mit einem Metrics-Endpoint und dem passenden ServiceMonitor aus:

```bash
kubectl create deployment ping-app --image=viktoruj/ping_pong:latest --replicas=1 -n eks-114
kubectl rollout status deployment/ping-app -n eks-114

kubectl expose deployment ping-app -n eks-114 --port=9090 --target-port=9090 \
  --name=ping-app
kubectl label service ping-app -n eks-114 app=ping-app --overwrite

kubectl -n eks-114 patch service ping-app --type merge -p '
spec:
  ports:
    - name: metrics
      port: 9090
      targetPort: 9090
'

cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ping-app
  namespace: eks-114
spec:
  selector:
    matchLabels:
      app: ping-app
  endpoints:
    - port: metrics
      path: /metrics
EOF
```

Wir warten, bis Prometheus das Target aufnimmt (normalerweise ein Scrape-Zyklus, bis zu einer
Minute), und fragen die Metrik über die API ab. Das Container-Image `prometheus` ist minimal
und enthält weder `wget` noch `curl`, noch nicht einmal `which` - `kubectl exec` für eine
HTTP-Anfrage funktioniert nicht. Einfacher ist es, den Port auf die Worker-Maschine
weiterzuleiten und die Anfrage von dort zu stellen:

```bash
sleep 60

kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 &
PF_PID=$!
sleep 5

mkdir -p /var/work/tests/artifacts/5
curl -s 'http://localhost:9090/api/v1/query?query=requests_total' \
  > /var/work/tests/artifacts/5/prom_query.txt
cat /var/work/tests/artifacts/5/prom_query.txt

kill "$PF_PID"
```

Der Name des Prometheus-Service ist `<release-name>-prometheus` (in dieser Lösung heißt der
Release `kube-prometheus-stack`, daher ist der Service `kube-prometheus-stack-prometheus` -
nicht zu verwechseln mit `prometheus-operated`, einem headless Service ohne ClusterIP).

Die Antwort - JSON mit `"status":"success"` und einem Array `"result"`, bei dem jedes Element
ein Feld `"metric"` hat - ist genau die Bestätigung, dass die Anwendungsmetrik über den
ServiceMonitor bei Prometheus angekommen ist und nicht über eine manuelle
`scrape_config`-Konfiguration.

## Aufgabe 6. Managed Prometheus: workspace ist bereit, Metriken zu empfangen

```bash
WORKSPACE_ID=$(aws amp list-workspaces --alias eks-task114-amp \
  --query 'workspaces[0].workspaceId' --output text)
echo "$WORKSPACE_ID"

mkdir -p /var/work/tests/artifacts/6
aws amp describe-workspace --workspace-id "$WORKSPACE_ID" \
  > /var/work/tests/artifacts/6/amp_endpoint.txt
cat /var/work/tests/artifacts/6/amp_endpoint.txt
```

In der Ausgabe enthält `workspace.prometheusEndpoint` `aps-workspaces.<region>.amazonaws.com` -
das ist der Endpoint für remote-write. Die eigentliche Sammel-Pipeline (managed collector oder
ADOT) gehört nicht zum Umfang dieser Lab: das Ziel ist zu zeigen, dass ein managed
Prometheus-kompatibles Backend bereits erstellt ist und bereit ist, Daten zu empfangen - der
dritte Metrikweg aus Kapitel 33 neben Container Insights und dem self-managed
kube-prometheus-stack.

## Schnelle Prüfung

```bash
check_result
```
