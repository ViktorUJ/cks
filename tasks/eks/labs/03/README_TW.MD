[Русская версия](README_RUS.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)


# 實驗課程：使用 KEDA 與 Prometheus 進行應用程式自動擴展

## 說明

本實驗課程示範如何根據 **Prometheus** 指標，透過 **KEDA**（Kubernetes Event-Driven Autoscaling）在 Amazon EKS 中自動擴展 Web 應用程式。應用程式會匯出自己的請求指標，Prometheus 會收集它們，而 KEDA 則會依實際每秒請求數（RPS）向上或向下擴展部署。

叢集已預先設定 **Karpenter** 與兩個專用 NodePool：
- `monitoring` — 用於監控堆疊（Prometheus、KEDA、metrics-server）
- `default` — 用於測試應用程式

**您將學習：**
- 如何透過 Helm 安裝官方 Prometheus Operator（kube-prometheus-stack）
- 如何使用 nodeAffinity 與 tolerations 將工作負載固定至專用節點
- 如何透過 LoadBalancer 發布 Prometheus 以便快速存取
- 如何透過 ServiceMonitor 收集自訂應用程式指標
- 如何安裝 KEDA 並根據 Prometheus 查詢設定 ScaledObject
- 如何產生負載並觀察自動向上／向下擴展
- 如何正確刪除雲端資源（LoadBalancer、Karpenter 節點）

## 目錄
- [準備環境](#準備環境)
  - [啟動實驗課程](#啟動實驗課程)
  - [建立的資源](#建立的資源)
  - [先決條件](#先決條件)
- [檢視 NodePool](#檢視-nodepool)
- [安裝監控堆疊](#安裝監控堆疊)
  - [Prometheus Operator 與 metrics-server](#prometheus-operator-與-metrics-server)
  - [驗證安裝](#驗證安裝)
- [部署應用程式](#部署應用程式)
- [收集應用程式指標](#收集應用程式指標)
  - [建立 ServiceMonitor](#建立-servicemonitor)
  - [驗證目標](#驗證目標)
  - [在 Prometheus 中驗證指標](#在-prometheus-中驗證指標)
- [安裝 KEDA](#安裝-keda)
- [設定自動擴展](#設定自動擴展)
  - [可用的應用程式指標](#可用的應用程式指標)
  - [建立 ScaledObject](#建立-scaledobject)
- [產生負載並觀察擴展](#產生負載並觀察擴展)
- [清理資源](#清理資源)
- [結論](#結論)


## 準備環境

### 啟動實驗課程
[透過 docker 啟動平台](https://github.com/ViktorUJ/cks/blob/master/docs%2Frun_from_docker.MD)

若要啟動實驗課程，請執行以下命令：

```bash
TASK=03 make run_eks_task
```

**執行此命令時會發生什麼：**
- Terraform/Terragrunt 會在 AWS 中自動部署所有必要基礎設施
- 此程序約需 15–20 分鐘
- 命令輸出會顯示重要資訊（SSH 連線、資源名稱）

### 建立的資源

執行命令時，將部署以下 AWS 基礎設施：

#### 網路基礎設施（VPC）
- 在 `eu-central-1` 區域中建立具有 CIDR 區塊 `10.10.0.0/16` 的 **VPC**
- 為可存取網際網路的資源建立 **公有子網路**（`eks-AZ-1`、`eks-AZ-2`）
- 為 EKS 節點和 RDS 建立 **私有子網路**
- 為私有子網路的對外網際網路流量建立 **NAT Gateway**

#### EKS 叢集
- 版本為 `1.35` 的 **EKS Control Plane**
- 用於系統 Pod（`kube-system`、`karpenter`）的 **Fargate 設定檔** — 請注意：CoreDNS 在 Fargate 上執行
- 版本為 `1.8.1` 的 **Karpenter**（自動擴展控制器）
- **EKS Add-ons**：coredns、kube-proxy、vpc-cni、eks-pod-identity-agent

#### 預先設定的 Karpenter NodePool
- **`default`** — 用於應用程式工作負載（30 秒後整合空節點）
- **`monitoring`** — 專用於監控堆疊，具有 taint `dedicated=monitoring:NoSchedule` 和 label `work_type=monitoring`（300 秒後整合）

#### 主要設定檔

所有基礎設施參數均定義於 `tasks/eks/labs/03/env.hcl` 檔案中。若要變更設定，請編輯此檔案中的相應參數。

### 先決條件

請確認您具備：
- 具有適當存取權限的 **AWS CLI**
- `eu-central-1` 區域中提高的節點限制（如有需要）
- 可透過 SSH 連至 worker 節點（請在 `make run_eks_task` 的輸出中查看連線字串）
- worker 節點上可用的 `kubectl`、`helm` 和 `jq`


## 檢視 NodePool

兩個 NodePool 已準備就緒。讓我們檢查它們：

```bash
kubectl get nodepools.karpenter.sh
```

**預期結果：**
```
NAME         NODECLASS    NODES   READY   AGE
default      default      0       True    2m46s
monitoring   monitoring   0       True    2m43s
```

- **`monitoring`** — 用於 Prometheus、KEDA 和 metrics-server
- **`default`** — 用於測試應用程式

更詳細地檢視 NodePool `monitoring`：

```bash
kubectl get nodepools.karpenter.sh monitoring -o yaml
```

**規格的關鍵部分：**
```yaml
spec:
  template:
    metadata:
      labels:
        work_type: monitoring        # 用於 nodeAffinity
    spec:
      taints:
      - effect: NoSchedule
        key: dedicated
        value: monitoring            # 只有具備相符 toleration 的 Pod 才會排程到此處
```

**這代表什麼：**監控 Pod 必須同時具有針對 `work_type=monitoring` 的 `nodeAffinity`，以及針對 `dedicated=monitoring:NoSchedule` 的 `toleration`。這可確保監控堆疊在專屬節點上執行，且不會有其他不必要的工作負載進入。


## 安裝監控堆疊

### Prometheus Operator 與 metrics-server

我們透過 Helm 安裝 **kube-prometheus-stack**（官方 Prometheus Operator）與 **metrics-server**。Grafana 已停用。所有元件都透過 `nodeAffinity` + `tolerations` 固定至 NodePool `monitoring`。

> **安全注意事項：**下方的 Prometheus Service 透過公有 LoadBalancer 發布，且**未經驗證**。這僅為實驗課程便利性而設。在 production 中，Prometheus 必須受到保護（驗證／OAuth2 proxy、透過 Security Groups 或 NetworkPolicy 的 IP 限制、具有 TLS 的 Ingress）。

```bash
# 新增 Helm 儲存庫
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# 建立 Prometheus values 檔案
cat <<'EOF' > prometheus-values.yaml
# 注意：Prometheus LoadBalancer 未經驗證即對外開放。
# 這僅供實驗課程使用。在 production 中，請使用
# 驗證、IP 限制（Security Groups / NetworkPolicy）及 TLS 保護 Prometheus。

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

# 建立 metrics-server values 檔案
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

# 安裝 Prometheus Operator
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

# 安裝 metrics-server
helm install metrics-server metrics-server/metrics-server \
  --namespace monitoring \
  -f metrics-server-values.yaml
```

**values 說明：**
- `serviceMonitorSelectorNilUsesHelmValues: false` + 空選擇器可讓 Prometheus 從**所有** namespace 擷取 ServiceMonitor（稍後收集應用程式指標時需要）。
- 每個元件皆宣告 `nodeAffinity`（`work_type=monitoring`），因此**只會**排程至監控節點。僅使用 `nodeSelector` 不足 — affinity 可保證放置位置。
- `node-exporter` 僅取得 toleration（它必須作為 DaemonSet 在每個節點上執行）。

### 驗證安裝

```bash
# 所有監控 Pod 都必須在監控節點上處於 Running 狀態
kubectl get pods -n monitoring -o wide

# 監控節點應已啟動
kubectl get nodes -l work_type=monitoring

# metrics-server 必須執行中
kubectl top nodes

# 取得 Prometheus LoadBalancer 位址（Prometheus UI 位於連接埠 9090）
kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' ; echo
```

請在瀏覽器開啟 `http://<LB-ADDRESS>:9090` 以存取 Prometheus UI。


## 部署應用程式

部署測試應用程式（`ping_pong`）。Service 發布兩個連接埠：`http`（80 → 8080）與 `metrics`（9090 → 9090）。

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

確認應用程式已啟動：

```bash
kubectl get po -n team-19
```

**預期結果：**
```
NAME                     READY   STATUS    RESTARTS   AGE
team19-598dc8484-vlqkd   1/1     Running   0          2m54s
```

檢查 NodeClaim — 應有一個專供監控的節點，另一個專供應用程式：

```bash
kubectl get nodeclaims.karpenter.sh
```

**預期結果：**
```
NAME               TYPE        CAPACITY   ZONE            NODE                                            READY   AGE
default-n5mxw      t4g.small   spot       eu-central-1a   ip-10-10-15-217.eu-central-1.compute.internal   True    16m
monitoring-rlm6f   t4g.small   spot       eu-central-1a   ip-10-10-15-53.eu-central-1.compute.internal    True    24m
```


## 收集應用程式指標

### 建立 ServiceMonitor

應用程式在連接埠 `9090` 的路徑 `/metrics` 匯出 Prometheus 指標。應用程式的 Service 已定義 `metrics` 連接埠，因此僅需要 ServiceMonitor。Label `release: prometheus` 可讓 Prometheus Operator 擷取它。

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

### 驗證目標

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 目標必須存在且健康（health: up）
curl -s "http://${PROM_URL}:9090/api/v1/targets" \
  | jq '.data.activeTargets[] | select(.labels.namespace=="team-19") | {endpoint: .scrapeUrl, health: .health}'
```

### 在 Prometheus 中驗證指標

```bash
PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 檢查 requests_total 指標
curl -s "http://${PROM_URL}:9090/api/v1/query" \
  --data-urlencode 'query=requests_total{namespace="team-19"}' | jq '.data.result'
```

若結果為空的 `[]`，表示尚未擷取 ServiceMonitor。請稍候後重試，或檢查上方目標的健康狀態。

您也可以在瀏覽器開啟 `http://<PROM_URL>:9090`，並在 Expression 欄位輸入 `requests_total`。

> **提示：**指標值會以 `"value": [<timestamp>, "<值>"]` 的形式傳回。第一個數字是抓取時間，第二個（字串）才是數值本身。在流量傳送至應用程式前，它會是 `0`。


## 安裝 KEDA

KEDA 與 Prometheus 在相同節點上執行（NodePool `monitoring`）。KEDA Helm chart 會將頂層 `tolerations` 和 `affinity` 套用至其**所有**元件（operator、metrics apiserver、webhooks）。

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

cat <<'EOF' > keda-values.yaml
# 適用於所有 KEDA 元件的全域 tolerations 與 affinity
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

### 驗證 KEDA

```bash
# KEDA Pod 必須在監控節點上處於 Running 狀態
kubectl get pods -n monitoring -l app.kubernetes.io/instance=keda -o wide

# 必須已安裝 KEDA CRD
kubectl get crd | grep keda
```

> **注意：**KEDA 的 `metrics-apiserver` 是內部 KEDA 元件（它為 Kubernetes HPA 提供外部指標）。這**不是**先前安裝的叢集 `metrics-server`；兩者皆為必要。


## 設定自動擴展

### 可用的應用程式指標

應用程式 `ping_pong` 匯出以下 Prometheus 指標（連接埠 9090、路徑 `/metrics`）：

| 指標 | 類型 | 說明 |
|---------|-----|----------|
| `requests_total` | Counter | 請求總數 |
| `requests_per_second` | Gauge | 即時 RPS（有雜訊，閒置時不會重設為 0） |
| `requests_per_minute` | Gauge | 即時 RPM |
| `goroutines` | Gauge | 目前 goroutine 數量 |

為進行擴展，我們使用 **`rate(requests_total[1m])`**，而不是原始 gauge `requests_per_second`。根據計數器的 `rate()` 會提供真正平滑的 RPS，它會隨負載線性增長，並在流量停止時確實降至 0 — 因此很容易選取閾值。

### 建立 ScaledObject

規則：副本 = `ceil(sum(rate(requests_total[1m])) / threshold)`。透過 `behavior` 設定快速縮減，以便負載降低後快速移除 Pod。

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
          # 快速縮減：10 秒穩定視窗，可移除最多 100% 的 Pod
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
      # rate(requests_total[1m]) -> 由計數器得出的真正 RPS；對所有 Pod 進行 sum。
      # 副本 = ceil(sum(rate) / threshold)
      query: sum(rate(requests_total{namespace="team-19", service="team19"}[1m]))
      threshold: "10"
      activationThreshold: "3"
EOF
```

**說明：**
- `threshold` — HPA 嘗試維持的**每個 Pod**目標 RPS。
- `activationThreshold: 3` 表示 KEDA 會在總 RPS 超過 3 前維持一個副本，可避免閒置時頻繁變動。
- `query` 使用 `sum(...)`（總 RPS，不受副本數影響），因此所需副本數保持穩定。在這裡使用 `avg(...)` 會在新增 Pod 時導致震盪。

檢查 ScaledObject 及其建立的 HPA：

```bash
kubectl get scaledobject -n team-19
kubectl get hpa -n team-19
```


## 產生負載並觀察擴展

啟動一個對應用程式 Service 產生負載的 Pod。內部迴圈傳送 N 個請求，外部 `sleep 1` 設定節奏 — 因此 `seq 1 N` 中的數字約等於目標 RPS。

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

### 觀察擴展

一個 `watch` 可同時顯示 Pod、HPA，以及 Prometheus 中每個 Pod 的 RPS。PromQL 查詢使用 URL 編碼（`--data-urlencode`），否則符號 `{`、`}` 與 `=` 會破壞剖析器。

```bash
export PROM_URL=$(kubectl get svc -n monitoring prometheus-kube-prometheus-prometheus -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

watch 'kubectl get pods -n team-19 ; echo ; kubectl get hpa -n team-19 ; echo ; echo -n "rps per pod = " ; curl -s "http://${PROM_URL}:9090/api/v1/query" --data-urlencode "query=sum(rate(requests_total{namespace=\"team-19\", service=\"team19\"}[1m])) / count(up{namespace=\"team-19\", service=\"team19\"})" | jq -r ".data.result[0].value[1]"'
```

**您應看到：**隨著負載增加，Pod 數量會趨近 `ceil(總_rps / threshold)`。HPA 的 `TARGETS` 欄（每個 Pod 的 RPS）與 watch 顯示的 `rps per pod` 相符。

> **調整提示：**Pod 數 ≈（`seq 1 N` 中的數字）/ threshold。使用 `seq 1 50` 與 `threshold: 10` 時，將得到約 5 個 Pod。增加數字即可取得更多 Pod。

### 停止負載

```bash
kubectl delete pod traffic-generator -n team-19
```

停止流量後，`rate(requests_total[1m])` 會降至 0。在 `cooldownPeriod`（10 秒）加上縮減穩定視窗（10 秒）內，KEDA 會擴展回 `minReplicaCount: 1`。


## 清理資源

### 刪除應用程式

```bash
# 刪除 ScaledObject（KEDA 將停止管理 HPA）
kubectl delete scaledobject team19-scaledobject -n team-19

# 刪除流量產生器（若仍在執行）
kubectl delete pod traffic-generator -n team-19 --ignore-not-found

# 刪除 ServiceMonitor
kubectl delete servicemonitor team19 -n team-19 --ignore-not-found

# 刪除應用程式本身（deployment、service、namespace）
kubectl delete -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/eks/labs/03/worker/files/tasks/1.yaml
```

### 刪除 Prometheus（重要：會刪除 LoadBalancer）

刪除 Helm release 會移除 LoadBalancer 類型的 Service，AWS 會釋放 ELB。

```bash
# 刪除 prometheus（這將刪除 Service LoadBalancer -> AWS ELB）
helm uninstall prometheus -n monitoring

# 刪除 metrics-server 和 keda
helm uninstall metrics-server -n monitoring
helm uninstall keda -n monitoring
```

確認 LoadBalancer（ELB）確實已刪除：

```bash
# prometheus Service 不應存在
kubectl get svc -n monitoring | grep prometheus

# 在 AWS 中確認 ELB 已刪除
aws elb describe-load-balancers --region eu-central-1 \
  --query "LoadBalancerDescriptions[].DNSName"
```

若 Service 因任何原因保留並阻擋 ELB 刪除，請手動刪除：

```bash
kubectl delete svc prometheus-kube-prometheus-prometheus -n monitoring --ignore-not-found
```

接著刪除 namespace：

```bash
kubectl delete namespace monitoring
```

> **重要：**務必在刪除節點或叢集**之前**刪除 LoadBalancer 類型的 Service。
> 若先刪除節點／叢集，AWS ELB 可能會以孤立資源的形式持續存在，
> 必須透過主控台或 CLI 手動刪除。

### 確認 Karpenter 已刪除所有節點

移除所有工作負載後，`default` 與 `monitoring` 節點會變成空的，Karpenter 應整合（刪除）它們。

```bash
# 觀察 nodeclaims 數量降至零
watch kubectl get nodeclaims.karpenter.sh
```

Karpenter 根據每個 NodePool 的 `consolidateAfter` 刪除空節點
（`default` = 30 秒、`monitoring` = 300 秒），因此監控節點需要較長時間才會刪除。

等待兩個命令皆傳回空結果：

```bash
kubectl get nodeclaims.karpenter.sh
kubectl get nodes -l work_type
```

若節點未刪除，請檢查妨礙整合的 Pod（例如沒有控制器的 Pod，或含有 `karpenter.sh/do-not-disrupt` 的 Pod）：

```bash
kubectl get pods -A -o wide --field-selector spec.nodeName=<имя-ноды>
```

### 刪除基礎設施

僅在 Karpenter 刪除所有節點後，才刪除實驗課程基礎設施：

```bash
TASK=03 make delete_eks_task
```

輸入 `y` 確認。刪除約需 10–15 分鐘。

> 在 Karpenter 刪除其節點前刪除基礎設施，可能會留下孤立的 EC2 執行個體。


## 結論

恭喜！您已在 EKS 上建立事件驅動自動擴展系統。

**您完成了：**

1. **監控堆疊** — 安裝官方 Prometheus Operator 與 metrics-server，並透過 nodeAffinity 與 tolerations 將其固定至專用節點
2. **發布** — 透過 LoadBalancer 發布 Prometheus 以快速存取（僅供實驗課程使用，未驗證）
3. **自訂指標** — 透過 ServiceMonitor 收集應用程式自身的請求指標
4. **KEDA** — 安裝 KEDA 並根據 Prometheus 查詢設定 ScaledObject
5. **自動擴展** — 使用 `rate(requests_total[1m])` 依實際 RPS 擴展應用程式，並快速縮減
6. **清理** — 正確移除 LoadBalancer，並在刪除基礎設施前讓 Karpenter 釋放節點

**關鍵重點：**

- 使用根據計數器的 `rate()` 以進行穩定、可預測的自動擴展，而非使用有雜訊的即時 gauge
- 在擴展器查詢中使用 `sum(...)`（而非 `avg(...)`），避免新增 Pod 時所需副本數震盪
- 透過 nodeAffinity **以及** tolerations 將基礎設施工作負載固定至專用節點
- 務必在刪除叢集前刪除 LoadBalancer 類型的 Service，以避免產生孤立的 ELB

**其他資源：**
- [KEDA 文件](https://keda.sh/docs/)
- [KEDA 中的 Prometheus scaler](https://keda.sh/docs/latest/scalers/prometheus/)
- [kube-prometheus-stack chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Karpenter 文件](https://karpenter.sh/docs/)
