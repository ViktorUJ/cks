[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 124 - 參考解決方案(HPA、KEDA、Prometheus)

所有命令都在工作機上透過 SSH 執行。kubectl 和 helm 已經配置好了(機器啟動時透過
`aws eks update-kubeconfig` 組裝 kubeconfig)。

## 任務 1. Namespace `eks-124`

```bash
kubectl create namespace eks-124
```

## 任務 2. namespace `monitoring` 中的 kube-prometheus-stack

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

這三個 flag 不是裝飾性的。這個實驗不需要 Grafana 或 Alertmanager,而 Grafana 是這個
chart 中最重的 pod(在測試台上大約 325 MiB)。明確的 `requests` 把 Prometheus 從
`BestEffort` 轉為 `Burstable`:排程器和 Karpenter(它是根據 `requests` 的總和來決定節
點大小的)都能看到它的需求。沒有這一步,監控堆疊會被塞進最便宜的 instance,kubelet
會在記憶體壓力下驅逐 Prometheus - 詳細分析見實驗的 README。

等待 pod 就緒:

```bash
kubectl get pods -n monitoring -w
```

等到所有 pod 都變成 `Running` 且 `1/1`(或 `2/2`)Ready - 通常需要 2-3 分鐘。檢查
KEDA 將要監看的 Service,以及 pod 的 QoS 類別:

```bash
kubectl get svc -n monitoring kube-prometheus-stack-prometheus
kubectl get pod -n monitoring prometheus-kube-prometheus-stack-prometheus-0 \
  -o jsonpath='{.status.qosClass}{"\n"}'
```

第二個命令預期的輸出是 `Burstable`。

## 任務 3. namespace `keda` 中的 KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update

helm install keda kedacore/keda --namespace keda --create-namespace
```

檢查 operator 和 metrics apiserver 是否已啟動:

```bash
kubectl get pods -n keda
```

預期結果:名稱類似 `keda-operator-...` 和 `keda-operator-metrics-apiserver-...` 的
pod 處於 `Running` 狀態。

## 任務 4. Deployment `demo-app`

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

## 任務 5. 帶有 `prometheus` scaler 的 ScaledObject

cAdvisor 指標 `container_cpu_usage_seconds_total` 是 kube-prometheus-stack 開箱即用地
從每個 pod 收集的,不需要任何 ServiceMonitor。我們計算的是任務 6 中負載生成器的 pod
的總 CPU 使用量,而不是 `demo-app` 自己的:這個應用程式是依據別人的負載來擴縮的,而
一般依 CPU 擴縮的 HPA 做不到這一點 - 外部指標存在的意義正是這個。

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

可以直接從集群中檢查這個查詢是否真的會回傳一些東西(在生成器還不存在時,結果會是空
的,這是正常的 - 這種情況下 KEDA 會向 HPA 回報零):

```bash
kubectl run promq --rm -i --restart=Never -n default --image=curlimages/curl -- \
  -sG --data-urlencode \
  'query=sum(rate(container_cpu_usage_seconds_total{namespace="eks-124",pod=~"stress-generator.*"}[1m]))' \
  http://kube-prometheus-stack-prometheus.monitoring.svc:9090/api/v1/query
```

檢查 KEDA 是否把 ScaledObject 納入管理並創建了 HPA:

```bash
kubectl get scaledobject demo-app -n eks-124
kubectl get hpa -A | grep keda-hpa
kubectl get hpa keda-hpa-demo-app -n eks-124
```

這個 HPA 叫做 `keda-hpa-demo-app` - 這就是證明:KEDA 並不會取代 HPA,它在底層創建並
管理的是一個普通的 `HorizontalPodAutoscaler`。

## 任務 6. 負載測試:向上擴縮

首先記錄負載施加之前的狀態:

```bash
mkdir -p /var/work/tests/artifacts/6
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_before.txt
cat /var/work/tests/artifacts/6/hpa_before.txt
```

創建負載生成器。它有自己的標籤(`app=stress-generator`) - 任務 5 中的 PromQL 查詢是
依照 pod 的名稱來選取的,不是依照標籤,所以把生成器混進 `demo-app` 的 selector 裡既
沒必要又有害:兩個 selector 互相重疊的 Deployment 是一種反模式。`limits.cpu` 是必須
的,否則四個 CPU worker 會讓 kubelet 拿不到 CPU,節點進入 `NotReady`。需要
`nodeSelector` 是因為 `polinux/stress` 只針對 `amd64` 建置,而這個實驗的 NodePool 同
時允許 `arm64`:

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

觀察指標和副本數量的成長:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

等待 1-2 分鐘(KEDA 會輪詢 Prometheus,HPA 會計算副本數,如果需要的話 Karpenter 會添
加一個節點)。在測試台上情況是這樣的:

```
06:36:41 replicas=1 0/100m (avg)
06:37:04 replicas=1 1251m/100m (avg)
06:37:26 replicas=4 382m/100m (avg)
```

一旦 `REPLICAS` 變得大於 `1`,就保存:

```bash
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/6/hpa_after.txt
cat /var/work/tests/artifacts/6/hpa_after.txt
```

## 任務 7. 移除負載:向下擴縮

```bash
kubectl delete deployment stress-generator -n eks-124
```

生成器的 pod 消失了,它們的序列從 Prometheus 中消失,KEDA 向 HPA 回報零。`TARGETS`
的值大約在 30 秒內降為零,但副本數量會保持不變:HPA 的 scaleDown
`stabilizationWindowSeconds` 預設為 300 秒。測試台上的一次實測 - 指標在 06:40:07 變
為零,副本數量在 06:44:40 和 06:45:07 分別經歷 `5 -> 2 -> 1`:

```bash
watch kubectl get hpa keda-hpa-demo-app -n eks-124
```

一旦 `REPLICAS` 回落到 `1`,就保存這個產物:

```bash
mkdir -p /var/work/tests/artifacts/7
kubectl get hpa keda-hpa-demo-app -n eks-124 > /var/work/tests/artifacts/7/hpa_after_cooldown.txt
cat /var/work/tests/artifacts/7/hpa_after_cooldown.txt
```

## 任務 8. 普通 HPA 與 KEDA 創建的 HPA 對比

```bash
kubectl get hpa -A
```

在輸出中,HPA `keda-hpa-demo-app` 從欄位上看起來跟普通 HPA 一模一樣 - 同樣的
`TARGETS`、`MINPODS`、`MAXPODS`、`REPLICAS`。唯一的差別是名稱(前綴 `keda-hpa-`)以及
是誰在控制它:普通的 HPA 是工程師直接透過 `HorizontalPodAutoscaler` manifest 創建並
編輯的,而 `keda-hpa-demo-app` 是由 KEDA operator 依據 `ScaledObject` 資源創建並控
制 - 也就是用 `управляется` 它,即控制它 - 刪除 `ScaledObject`,KEDA 就會把這個 HPA
也一起刪掉。

把解釋保存到產物中:

```bash
mkdir -p /var/work/tests/artifacts/8
cat > /var/work/tests/artifacts/8/hpa_compare.txt <<'EOF'
在 kubectl get hpa -A 的輸出中,普通 HPA 和 HPA keda-hpa-demo-app 在欄位上看起來一模一
樣:TARGETS/MINPODS/MAXPODS/REPLICAS - 唯一的差別在於名稱,以及物件的來源出處。

KEDA 並不會取代 HPA:KEDA operator 監看著 ScaledObject,並自己創建、управляет(控制)
一個名為 keda-hpa-<ScaledObject 名稱> 的普通 HorizontalPodAutoscaler,而 KEDA 的
metrics adapter 則透過 external.metrics.k8s.io 為它提供指標數值。副本數量仍然是由一
直以來相同的 HPA 機制來計算的。
EOF
cat /var/work/tests/artifacts/8/hpa_compare.txt
```

## 快速檢查

```bash
check_result
```
