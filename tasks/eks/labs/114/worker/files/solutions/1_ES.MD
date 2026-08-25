[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 114 - solución de referencia (observabilidad: Container Insights y Managed Prometheus)

Todos los comandos se ejecutan en la máquina de trabajo (worker) por SSH. kubectl y helm ya
están configurados. Terraform ya creó el AMP workspace, su alias está registrado en
`~/lab114_hints.txt`.

```bash
cat ~/lab114_hints.txt
```

## Tarea 1. Namespace `eks-114`

```bash
kubectl create namespace eks-114
```

## Tarea 2. Síntoma: no hay métricas en absoluto

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

Ambos comandos fallan con `error: Metrics API not available` - la Metrics API
(`metrics.k8s.io`) no está registrada, porque metrics-server todavía no está instalado.

## Tarea 3. Capa base: addon metrics-server

```bash
CLUSTER_NAME=$(kubectl config current-context | sed 's|.*/||')

aws eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" --addon-name metrics-server
aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
  --query 'addon.status'
```

Esperamos hasta que la Metrics API empiece a devolver números reales (normalmente tarda uno
o dos minutos después de que el addon quede `ACTIVE`):

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

## Tarea 4. Container Insights: addon amazon-cloudwatch-observability

El addon necesita permisos de publicación en CloudWatch. EKS Pod Identity no usa el
proveedor OIDC del clúster, así que la trust policy del rol confía directamente en el
servicio `pods.eks.amazonaws.com`:

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

Instalamos el addon con la asociación Pod Identity hacia este ServiceAccount:

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

## Tarea 5. kube-prometheus-stack: recolección real de métricas de la aplicación

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=300s
```

`serviceMonitorSelectorNilUsesHelmValues=false` es importante: sin él, Prometheus solo verá
el ServiceMonitor de su propio Helm release e ignorará `ping-app` de otro namespace.

Desplegamos la aplicación con el endpoint de métricas y el ServiceMonitor hacia ella:

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

Esperamos a que Prometheus recoja el target (normalmente un ciclo de scrape, hasta un
minuto), y consultamos la métrica mediante la API. La imagen del contenedor `prometheus` es
mínima y no contiene ni `wget`, ni `curl`, ni siquiera `which` - `kubectl exec` para una
petición HTTP no funcionará. Es más simple redirigir el puerto a la máquina de trabajo y
hacer la petición desde ahí:

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

El nombre del servicio de Prometheus es `<nombre-release>-prometheus` (en esta solución el
release se llama `kube-prometheus-stack`, por lo que el servicio es
`kube-prometheus-stack-prometheus`; no confundir con `prometheus-operated`, un servicio
headless sin ClusterIP).

La respuesta es un JSON con `"status":"success"` y un array `"result"`, donde cada elemento
tiene el campo `"metric"` - esto confirma que la métrica de la aplicación llegó a Prometheus
a través del ServiceMonitor, y no mediante una configuración manual de `scrape_config`.

## Tarea 6. Managed Prometheus: el workspace está listo para recibir métricas

```bash
WORKSPACE_ID=$(aws amp list-workspaces --alias eks-task114-amp \
  --query 'workspaces[0].workspaceId' --output text)
echo "$WORKSPACE_ID"

mkdir -p /var/work/tests/artifacts/6
aws amp describe-workspace --workspace-id "$WORKSPACE_ID" \
  > /var/work/tests/artifacts/6/amp_endpoint.txt
cat /var/work/tests/artifacts/6/amp_endpoint.txt
```

En la salida, `workspace.prometheusEndpoint` contiene `aps-workspaces.<region>.amazonaws.com`
- este es el endpoint para remote-write. El propio pipeline de recolección (managed
collector o ADOT) no forma parte del alcance de esta laba: el objetivo es demostrar que el
backend compatible con Prometheus managed ya está creado y listo para recibir datos, el
tercer camino de métricas del capítulo 33 junto a Container Insights y el
kube-prometheus-stack self-managed.

## Verificación rápida

```bash
check_result
```
