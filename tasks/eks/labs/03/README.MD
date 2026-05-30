[Russian version](README_RUS.MD)


# Lab: Application Autoscaling with KEDA and Prometheus

## Description

This lab shows how to autoscale a web application on Amazon EKS using **KEDA** (Kubernetes Event-Driven Autoscaling) based on **Prometheus** metrics. The application exposes its own request metrics, Prometheus scrapes them, and KEDA scales the deployment up and down according to the real request rate (RPS).

The cluster comes pre-provisioned with **Karpenter** and two dedicated NodePools:
- `monitoring` — for the monitoring stack (Prometheus, KEDA, metrics-server)
- `default` — for the test application

**What you will learn:**
- How to install the official Prometheus Operator (kube-prometheus-stack) via Helm
- How to pin workloads to dedicated nodes using nodeAffinity and tolerations
- How to expose Prometheus through a LoadBalancer for quick access
- How to scrape custom application metrics with a ServiceMonitor
- How to install KEDA and configure a ScaledObject driven by a Prometheus query
- How to generate load and observe automatic scale up / scale down
- How to clean up cloud resources correctly (LoadBalancer, Karpenter nodes)

## Table of Contents
- [Environment Setup](#environment-setup)
  - [Starting the Lab](#starting-the-lab)
  - [Resources Created](#resources-created)
  - [Prerequisites](#prerequisites)
- [Inspecting the NodePools](#inspecting-the-nodepools)
- [Installing the Monitoring Stack](#installing-the-monitoring-stack)
  - [Prometheus Operator and metrics-server](#prometheus-operator-and-metrics-server)
  - [Verifying the Installation](#verifying-the-installation)
- [Deploying the Application](#deploying-the-application)
- [Scraping Application Metrics](#scraping-application-metrics)
  - [Creating a ServiceMonitor](#creating-a-servicemonitor)
  - [Verifying the Target](#verifying-the-target)
  - [Verifying Metrics in Prometheus](#verifying-metrics-in-prometheus)
- [Installing KEDA](#installing-keda)
- [Configuring Autoscaling](#configuring-autoscaling)
  - [Available Application Metrics](#available-application-metrics)
  - [Creating the ScaledObject](#creating-the-scaledobject)
- [Generating Load and Observing Scaling](#generating-load-and-observing-scaling)
- [Resource Cleanup](#resource-cleanup)
- [Conclusion](#conclusion)


## Environment Setup

### Starting the Lab
[Run platform via docker](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

To start the lab, run the following command:

```bash
TASK=03 make run_eks_task
```

**What happens when you run this command:**
- Terraform/Terragrunt automatically deploys all necessary infrastructure in AWS
- The process takes approximately 15-20 minutes
- The command output will show important information (SSH connection, resource names)

### Resources Created

When you run the command, the following AWS infrastructure will be deployed:

#### Network Infrastructure (VPC)
- **VPC** with CIDR block `10.10.0.0/16` in region `eu-central-1`
- **Public subnets** for resources with internet access (`eks-AZ-1`, `eks-AZ-2`)
- **Private subnets** for EKS nodes and RDS
- **NAT Gateway** for outbound internet traffic from private subnets

#### EKS Cluster
- **EKS Control Plane** version `1.35`
- **Fargate profile** for system pods (`kube-system`, `karpenter`) — note: CoreDNS runs on Fargate
- **Karpenter** version `1.8.1` (autoscaling controller)
- **EKS Add-ons**: coredns, kube-proxy, vpc-cni, eks-pod-identity-agent

#### Pre-configured Karpenter NodePools
- **`default`** — for application workloads (consolidates empty nodes after 30s)
- **`monitoring`** — dedicated to the monitoring stack, tainted with `dedicated=monitoring:NoSchedule` and labeled `work_type=monitoring` (consolidates after 300s)

#### Main Configuration File

All infrastructure parameters are defined in `tasks/eks/labs/03/env.hcl`. To change the configuration, edit the appropriate parameters in this file.

### Prerequisites

Make sure you have:
- **AWS CLI** with appropriate access rights
- Increased node limits in the `eu-central-1` region (if necessary)
- Connected to the worker node via SSH (find the connection string in the `make run_eks_task` output)
- `kubectl`, `helm`, and `jq` available on the worker node


## Inspecting the NodePools

Two NodePools are pre-provisioned. Check them:

```bash
kubectl get nodepools.karpenter.sh
```

**Expected result:**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — runs Prometheus, KEDA and metrics-server
- **`default`** — runs the test application

Look at the `monitoring` NodePool in detail:

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**Key parts of the spec:**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # used by nodeAffinity
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # only pods with matching toleration land here
```

**What this means:** monitoring pods must have both a `nodeAffinity` for `work_type=monitoring` and a `toleration` for `dedicated=monitoring:NoSchedule`. This guarantees the monitoring stack runs on its own nodes and nothing else schedules there.


## Installing the Monitoring Stack

### Prometheus Operator and metrics-server

We install **kube-prometheus-stack** (the official Prometheus Operator) and **metrics-server** via Helm. Grafana is disabled. All components are pinned to the `monitoring` NodePool with `nodeAffinity` + `tolerations`.

> **Security note:** the Prometheus Service below is exposed via a public LoadBalancer **without authentication**. This is done for lab convenience only. In production, Prometheus must be protected (authentication / OAuth2 proxy, IP allow-lists via Security Groups or NetworkPolicy, Ingress with TLS).

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Create the Prometheus values file
cat <<'EOF' > prometheus-values.yaml
# WARNING: the Prometheus LoadBalancer is exposed without authentication.
# This is for the lab only. In production, secure Prometheus with auth,
# IP allow-lists (Security Groups / NetworkPolicy) and TLS.

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

# Create the metrics-server values file
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

# Install the Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# Install metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**Note on the values:**
- `serviceMonitorSelectorNilUsesHelmValues: false` + empty selectors let Prometheus pick up ServiceMonitors from **all** namespaces (needed to scrape the app later).
- Every component declares `nodeAffinity` (`work_type=monitoring`) so it is scheduled **only** on monitoring nodes. `nodeSelector` alone is not enough — affinity guarantees placement.
- `node-exporter` only gets a toleration (it must run on every node as a DaemonSet).

### Verifying the Installation

```bash
# All monitoring pods should be Running on monitoring nodes
kubectl get pods -n monitoring -o wide

# Monitoring nodes should be up
kubectl get nodes -l work_type=monitoring

# metrics-server should work
kubectl top nodes

# Get the Prometheus LoadBalancer address (Prometheus UI is on port 9090)
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

Open `http://<LB-ADDRESS>:9090` in a browser to access the Prometheus UI.


## Deploying the Application

Deploy the test application (`ping_pong`). The Service exposes two ports: `http` (80 → 8080) and `metrics` (9090 → 9090).

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-143/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

Check that the application is running:

```bash
kubectl get po -n team-19
```

**Expected result:**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

Check the NodeClaims — there should be a separate node for monitoring and a separate node for the application:

```bash
kubectl get nodeclaims.karpenter.sh
```

**Expected result:**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## Scraping Application Metrics

### Creating a ServiceMonitor

The application exposes Prometheus metrics on port `9090` at `/metrics`. The `metrics` port is already defined on the application Service, so we only need a ServiceMonitor. The `release: prometheus` label lets the Prometheus Operator pick it up.

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

### Verifying the Target

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# The target should be present and healthy (health: up)
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### Verifying Metrics in Prometheus

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Check the requests_total metric
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

If the result is empty `[]`, the ServiceMonitor has not been picked up yet — wait a bit and retry, or check the target health above.

You can also open `http://<PROM_URL>:9090` in a browser and type `requests_total` in the Expression field.

> **Tip:** the metric value comes back as `"value": [<timestamp>, "<value>"]`. The first number is the scrape timestamp, the second (string) is the actual value. It will be `0` until traffic reaches the app.


## Installing KEDA

KEDA runs on the same nodes as Prometheus (the `monitoring` NodePool). The KEDA Helm chart applies the top-level `tolerations` and `affinity` to **all** its components (operator, metrics apiserver, webhooks).

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# Global tolerations and affinity applied to all KEDA components
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

### Verifying KEDA

```bash
# KEDA pods should be Running on monitoring nodes
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# KEDA CRDs should be installed
kubectl get crd | grep keda
```

> **Note:** the KEDA `metrics-apiserver` is an internal KEDA component (it exposes external metrics to the Kubernetes HPA). It is **not** the same as the cluster `metrics-server` we installed earlier — both are required.


## Configuring Autoscaling

### Available Application Metrics

The `ping_pong` application exposes these Prometheus metrics (port 9090, path `/metrics`):

| Metric | Type | Description |
|--------|------|-------------|
| `requests_total` | Counter | Total number of requests |
| `requests_per_second` | Gauge | Instantaneous RPS (noisy, does not reset to 0 when idle) |
| `requests_per_minute` | Gauge | Instantaneous RPM |
| `goroutines` | Gauge | Current number of goroutines |

We scale on **`rate(requests_total[1m])`** rather than the raw `requests_per_second` gauge. The counter-based `rate()` gives a true, smoothed RPS that grows linearly with load and honestly falls back to 0 when traffic stops — which makes the threshold easy to reason about.

### Creating the ScaledObject

The rule: replicas = `ceil(sum(rate(requests_total[1m])) / threshold)`. A fast scale-down `behavior` is configured so pods are removed quickly after load drops.

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
          # Fast scale down: 10s stabilization window, can remove up to 100% of pods
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
      # rate(requests_total[1m]) -> true RPS from the counter; sum across all pods.
      # replicas = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**Notes:**
- `threshold` is the target RPS **per pod** that the HPA aims to maintain.
- `activationThreshold: 3` means KEDA keeps a single replica until total RPS exceeds 3, avoiding flapping at idle.
- The `query` uses `sum(...)` (total RPS, independent of replica count) so the desired replica count is stable. Using `avg(...)` here would oscillate as pods are added.

Check the ScaledObject and the HPA it generates:

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## Generating Load and Observing Scaling

Start a pod that generates load against the application Service. The inner loop fires N requests, the outer `sleep 1` paces them — so the number in `seq 1 N` is roughly the target RPS.

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

### Observing the Scaling

A single `watch` shows pods, the HPA, and the per-pod RPS from Prometheus at once. The PromQL query is URL-encoded (`--data-urlencode`), otherwise the `{`, `}` and `=` characters break the parser.

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**What you should see:** as load ramps up, the pod count grows toward `ceil(total_rps / threshold)`. The HPA `TARGETS` column (RPS per pod) matches the `rps per pod` printed by the watch.

> **Sizing tip:** pods ≈ (number in `seq 1 N`) / threshold. With `seq 1 50` and `threshold: 10` you get about 5 pods. Increase the number to get more pods.

### Stopping the Load

```bash
kubectl delete pod traffic-generator -n team-19
```

After traffic stops, `rate(requests_total[1m])` decays to 0. Within the `cooldownPeriod` (10s) plus the scale-down stabilization window (10s), KEDA scales back down to `minReplicaCount: 1`.


## Resource Cleanup

### Deleting the Application

```bash
# Delete the ScaledObject (KEDA stops managing the HPA)
kubectl delete scaledobject team19-scaledobject -n team-19

# Delete the traffic generator (if still running)
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# Delete the ServiceMonitor
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# Delete the application itself (deployment, service, namespace)
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/AG-143/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### Deleting Prometheus (important: removes the LoadBalancer)

Uninstalling the Helm release deletes the LoadBalancer Service, which makes AWS release the ELB.

```bash
# Delete prometheus (this removes the LoadBalancer Service -> AWS ELB)
helm uninstall prometheus -n monitoring

# Delete metrics-server and keda
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

Verify the LoadBalancer (ELB) was actually removed:

```bash
# The prometheus Service should no longer exist
kubectl get svc -n monitoring | grep prometheus

# Confirm in AWS that the ELB is gone
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

If the Service somehow remains and blocks ELB deletion, delete it manually:

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

Then delete the namespace:

```bash
kubectl delete namespace monitoring
```

> **Important:** always delete the LoadBalancer Service **before** deleting nodes or the cluster.
> If you tear down the nodes/cluster first, the AWS ELB can be left orphaned and you will have to
> remove it manually through the console or CLI.

### Verifying Karpenter Removed All Nodes

Once all workloads are gone, the `default` and `monitoring` nodes become empty and Karpenter should consolidate (delete) them.

```bash
# Watch the nodeclaims shrink to zero over time
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter deletes empty nodes according to each NodePool's `consolidateAfter`
(`default` = 30s, `monitoring` = 300s), so monitoring nodes take longer.

Wait until both commands return nothing:

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

If a node is not removed, check for pods that block consolidation (e.g. pods without a controller or with `karpenter.sh/do-not-disrupt`):

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<node-name>
```

### Deleting the Infrastructure

Only after Karpenter has removed all nodes, delete the lab infrastructure:

```bash
TASK=03 make delete_eks_task
```

Enter `y` to confirm. The deletion takes approximately 10-15 minutes.

> Deleting infrastructure before Karpenter removes its nodes can leave orphaned EC2 instances.


## Conclusion

Congratulations! You have built an event-driven autoscaling setup on EKS.

**What you accomplished:**

1. **Monitoring stack** — installed the official Prometheus Operator and metrics-server, pinned to dedicated nodes with nodeAffinity and tolerations
2. **Exposure** — published Prometheus through a LoadBalancer for quick access (lab-only, unauthenticated)
3. **Custom metrics** — scraped the application's own request metrics with a ServiceMonitor
4. **KEDA** — installed KEDA and configured a ScaledObject driven by a Prometheus query
5. **Autoscaling** — scaled the application on real RPS using `rate(requests_total[1m])`, with fast scale-down behavior
6. **Cleanup** — removed the LoadBalancer correctly and let Karpenter reclaim the nodes before tearing down infrastructure

**Key takeaways:**

- Use counter-based `rate()` for stable, predictable autoscaling instead of noisy instantaneous gauges
- Use `sum(...)` (not `avg(...)`) in the scaler query so the desired replica count does not oscillate as pods are added
- Pin infrastructure workloads to dedicated nodes with nodeAffinity **and** tolerations
- Always delete LoadBalancer Services before tearing down the cluster to avoid orphaned ELBs

**Additional resources:**
- [KEDA documentation](https://keda.sh/docs/)
- [KEDA Prometheus scaler](https://keda.sh/docs/latest/scalers/prometheus/)
- [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Karpenter documentation](https://karpenter.sh/docs/)
