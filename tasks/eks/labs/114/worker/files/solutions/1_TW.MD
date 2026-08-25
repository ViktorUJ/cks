[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 114 - 參考解決方案(可觀測性:Container Insights 與 Managed Prometheus)

所有命令都在工作機(worker)上透過 SSH 執行。kubectl 和 helm 已經配置好。Terraform 已
經創建了 AMP workspace,它的 alias 記錄在 `~/lab114_hints.txt` 中。

```bash
cat ~/lab114_hints.txt
```

## 任務 1。Namespace `eks-114`

```bash
kubectl create namespace eks-114
```

## 任務 2。症狀:完全沒有指標

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

兩個命令都會失敗,報 `error: Metrics API not available` - Metrics API
(`metrics.k8s.io`)還沒有註冊,因為 metrics-server 還沒安裝。

## 任務 3。基礎層:附加元件 metrics-server

```bash
CLUSTER_NAME=$(kubectl config current-context | sed 's|.*/||')

aws eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" --addon-name metrics-server
aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
  --query 'addon.status'
```

等待 Metrics API 開始回傳真實數字(附加元件進入 `ACTIVE` 之後,通常需要一兩分鐘):

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

## 任務 4。Container Insights:附加元件 amazon-cloudwatch-observability

附加元件需要向 CloudWatch 發佈資料的權限。EKS Pod Identity 不使用集群的 OIDC
provider,所以角色的 trust policy 直接信任服務 `pods.eks.amazonaws.com`:

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

用 Pod Identity association 把這個 ServiceAccount 綁到附加元件上:

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

## 任務 5。kube-prometheus-stack:真正收集應用程式指標

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=300s
```

`serviceMonitorSelectorNilUsesHelmValues=false` 很關鍵:如果不設定,Prometheus 只會看
到自己 Helm release 中的 ServiceMonitor,而忽略其他 namespace 中的 `ping-app`。

部署帶有指標端點的應用程式,以及對應的 ServiceMonitor:

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

等待 Prometheus 抓取到這個目標(通常一個抓取週期,最多一分鐘),然後透過 API 查詢指
標。容器 `prometheus` 的映像非常精簡,沒有 `wget`、沒有 `curl`,連 `which` 都沒有 -
`kubectl exec` 沒辦法用來發 HTTP 請求。更簡單的做法是把端口轉發到工作機,再從那裡發
請求:

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

Prometheus 服務的名稱是 `<release名稱>-prometheus`(在這個解決方案中,release 叫做
`kube-prometheus-stack`,所以服務是 `kube-prometheus-stack-prometheus`;不要和
`prometheus-operated` 搞混,那是一個沒有 ClusterIP 的 headless 服務)。

回應是一個帶有 `"status":"success"` 的 JSON,以及一個 `"result"` 陣列,其中每個元素都
有 `"metric"` 這個欄位 - 這正好證明應用程式的指標已經透過 ServiceMonitor 抵達了
Prometheus,而不是透過手動設定的 `scrape_config`。

## 任務 6。Managed Prometheus:workspace 已準備好接收指標

```bash
WORKSPACE_ID=$(aws amp list-workspaces --alias eks-task114-amp \
  --query 'workspaces[0].workspaceId' --output text)
echo "$WORKSPACE_ID"

mkdir -p /var/work/tests/artifacts/6
aws amp describe-workspace --workspace-id "$WORKSPACE_ID" \
  > /var/work/tests/artifacts/6/amp_endpoint.txt
cat /var/work/tests/artifacts/6/amp_endpoint.txt
```

輸出中的 `workspace.prometheusEndpoint` 包含 `aps-workspaces.<region>.amazonaws.com` -
這是 remote-write 用的 endpoint。收集管線本身(managed collector 或 ADOT)不在這個實
驗的範圍內:目的是證明 managed Prometheus 相容後端已經創建好,並準備好接收資料 - 這是
第 33 章中與 Container Insights 和 self-managed kube-prometheus-stack 並列的第三條指
標路徑。

## 快速檢查

```bash
check_result
```
