[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 114 - solution de référence (observabilité : Container Insights et Managed Prometheus)

Toutes les commandes s'exécutent sur la machine worker via SSH. kubectl et helm sont déjà configurés.
Terraform a déjà créé le AMP workspace, son alias est enregistré dans `~/lab114_hints.txt`.

```bash
cat ~/lab114_hints.txt
```

## Tâche 1. Namespace `eks-114`

```bash
kubectl create namespace eks-114
```

## Tâche 2. Symptôme : aucune métrique du tout

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

Les deux commandes échouent avec `error: Metrics API not available` - la Metrics API
(`metrics.k8s.io`) n'est pas enregistrée, car metrics-server n'est pas encore installé.

## Tâche 3. Couche de base : addon metrics-server

```bash
CLUSTER_NAME=$(kubectl config current-context | sed 's|.*/||')

aws eks create-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server

aws eks wait addon-active --cluster-name "$CLUSTER_NAME" --addon-name metrics-server
aws eks describe-addon --cluster-name "$CLUSTER_NAME" --addon-name metrics-server \
  --query 'addon.status'
```

On attend que la Metrics API commence à renvoyer des chiffres réels (en général une à deux
minutes après que l'addon est passé à `ACTIVE`) :

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

## Tâche 4. Container Insights : addon amazon-cloudwatch-observability

L'addon a besoin de droits pour publier dans CloudWatch. EKS Pod Identity n'utilise pas le
fournisseur OIDC du cluster, donc la trust policy du rôle fait confiance directement au
service `pods.eks.amazonaws.com` :

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

On installe l'addon avec l'association Pod Identity sur ce ServiceAccount :

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

## Tâche 5. kube-prometheus-stack : collecte réelle des métriques applicatives

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

kubectl rollout status statefulset/prometheus-kube-prometheus-stack-prometheus \
  -n monitoring --timeout=300s
```

`serviceMonitorSelectorNilUsesHelmValues=false` est important : sans cela, Prometheus ne
verra que le ServiceMonitor de son propre release Helm et ignorera `ping-app` d'un autre
namespace.

On déploie l'application avec son endpoint de métriques et le ServiceMonitor associé :

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

On attend que Prometheus prenne en compte la cible (en général un cycle de scrape, jusqu'à
une minute), et on interroge la métrique via l'API. L'image du conteneur `prometheus` est
minimale et ne contient ni `wget`, ni `curl`, ni même `which` - `kubectl exec` pour une
requête HTTP ne fonctionnera pas. Il est plus simple de rediriger le port vers la machine
worker et d'y faire la requête :

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

Le nom du service Prometheus est `<nom-du-release>-prometheus` (dans cette solution, le
release s'appelle `kube-prometheus-stack`, donc le service est
`kube-prometheus-stack-prometheus` - à ne pas confondre avec `prometheus-operated`, un
service headless sans ClusterIP).

La réponse est un JSON avec `"status":"success"` et un tableau `"result"`, où chaque
élément a un champ `"metric"` - c'est la confirmation que la métrique applicative est bien
arrivée jusqu'à Prometheus via le ServiceMonitor, et non via une configuration manuelle de
`scrape_config`.

## Tâche 6. Managed Prometheus : le workspace est prêt à recevoir des métriques

```bash
WORKSPACE_ID=$(aws amp list-workspaces --alias eks-task114-amp \
  --query 'workspaces[0].workspaceId' --output text)
echo "$WORKSPACE_ID"

mkdir -p /var/work/tests/artifacts/6
aws amp describe-workspace --workspace-id "$WORKSPACE_ID" \
  > /var/work/tests/artifacts/6/amp_endpoint.txt
cat /var/work/tests/artifacts/6/amp_endpoint.txt
```

Dans la sortie, `workspace.prometheusEndpoint` contient `aps-workspaces.<region>.amazonaws.com` -
c'est l'endpoint pour le remote-write. Le pipeline de collecte lui-même (managed collector
ou ADOT) n'entre pas dans le périmètre de cette lab : l'objectif est de montrer qu'un backend
managé compatible Prometheus est déjà créé et prêt à recevoir des données, un troisième
chemin de métriques du chapitre 33, à côté de Container Insights et de la
kube-prometheus-stack self-managed.

## Vérification rapide

```bash
check_result
```
