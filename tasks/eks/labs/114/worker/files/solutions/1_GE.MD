[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბა 114 - ეტალონური გადაწყვეტა (დაკვირვებადობა: Container Insights და Managed Prometheus)

ყველა ბრძანება სრულდება სამუშაო მანქანაზე (worker) SSH-ის მეშვეობით. kubectl და helm უკვე
კონფიგურირებულია.
Terraform-მა უკვე შექმნა AMP workspace, მისი alias ჩაწერილია `~/lab114_hints.txt`-ში.

```bash
cat ~/lab114_hints.txt
```

## დავალება 1. Namespace `eks-114`

```bash
kubectl create namespace eks-114
```

## დავალება 2. სიმპტომი: მეტრიკები არ არსებობს საერთოდ

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

ორივე ბრძანება ეცემა `error: Metrics API not available`-ით - Metrics API (`metrics.k8s.io`)
არ არის დარეგისტრირებული, რადგან metrics-server ჯერ არ დაყენებულა.

## დავალება 3. ბაზისური შრე: addon metrics-server

```bash
CLUSTER_NAME=$(kubectl config current-context | sed 's|.*/||')

aws eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" --addon-name metrics-server
aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
  --query 'addon.status'
```

ველოდებით, სანამ Metrics API დაიწყებს რეალური რიცხვების დაბრუნებას (ჩვეულებრივ იღებს
წუთ-ორ წუთს მას შემდეგ, რაც addon გახდა `ACTIVE`):

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

## დავალება 4. Container Insights: addon amazon-cloudwatch-observability

Addon-ს სჭირდება უფლებები CloudWatch-ში პუბლიკაციისთვის. EKS Pod Identity არ იყენებს
კლასტერის OIDC-provider-ს, ამიტომ როლის trust policy პირდაპირ ეყრდნობა სერვისს
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

ვდგამთ addon-ს Pod Identity association-ით ამ ServiceAccount-ზე:

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

## დავალება 5. kube-prometheus-stack: აპლიკაციის მეტრიკების რეალური შეგროვება

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=300s
```

`serviceMonitorSelectorNilUsesHelmValues=false` მნიშვნელოვანია: მის გარეშე Prometheus
დაინახავს მხოლოდ ServiceMonitor-ს საკუთარი Helm-რელიზიდან და უგულებელყოფს `ping-app`-ს
სხვა namespace-იდან.

ვშლით აპლიკაციას მეტრიკების endpoint-ითა და ServiceMonitor-ით მასზე:

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

ველოდებით, სანამ Prometheus დაიჭერს target-ს (ჩვეულებრივ ერთი scrape-ციკლი, წუთამდე), და
ვითხოვთ მეტრიკას API-ის მეშვეობით. კონტეინერის image `prometheus` მინიმალურია და არ
შეიცავს არც `wget`-ს, არც `curl`-ს, არც `which`-საც კი - `kubectl exec` HTTP-request-ისთვის
არ იმუშავებს. უფრო ადვილია port გადავმართოთ სამუშაო მანქანაზე და request გავაკეთოთ
იქიდან:

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

Prometheus-ის სერვისის სახელი - `<რელიზის-სახელი>-prometheus` (ამ გადაწყვეტაში რელიზს
ეწოდება `kube-prometheus-stack`, ამიტომ სერვისი - `kube-prometheus-stack-prometheus`; არ
შევეშალოთ `prometheus-operated`-ს, headless-სერვისს ClusterIP-ის გარეშე).

პასუხი - JSON `"status":"success"`-ით და მასივით `"result"`, სადაც ყოველ ელემენტს აქვს
ველი `"metric"` - ეს არის დასტური, რომ აპლიკაციის მეტრიკა მიწვდა Prometheus-ს
ServiceMonitor-ის მეშვეობით, არა ხელით კონფიგურირებული `scrape_config`-ის მეშვეობით.

## დავალება 6. Managed Prometheus: workspace მზადაა მეტრიკების მისაღებად

```bash
WORKSPACE_ID=$(aws amp list-workspaces --alias eks-task114-amp \
  --query 'workspaces[0].workspaceId' --output text)
echo "$WORKSPACE_ID"

mkdir -p /var/work/tests/artifacts/6
aws amp describe-workspace --workspace-id "$WORKSPACE_ID" \
  > /var/work/tests/artifacts/6/amp_endpoint.txt
cat /var/work/tests/artifacts/6/amp_endpoint.txt
```

Output-ში `workspace.prometheusEndpoint` შეიცავს `aps-workspaces.<region>.amazonaws.com` -
ეს არის endpoint remote-write-ისთვის. თავად collection-ის pipeline (managed collector ან
ADOT) ამ ლაბის ფარგლებში არ შედის: მიზანი - ვაჩვენოთ, რომ managed Prometheus-თან
თანხმლები backend უკვე შექმნილია და მზადაა მონაცემების მისაღებად, მეტრიკების მესამე გზა
თავი 33-დან Container Insights-ისა და self-managed kube-prometheus-stack-ის გვერდით.

## სწრაფი შემოწმება

```bash
check_result
```
