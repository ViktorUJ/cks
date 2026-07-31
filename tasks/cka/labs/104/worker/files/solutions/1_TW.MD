[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 104 - 參考解答（排程、資源、HPA）

## 題目 1. 把 Pod `alpine` 放到帶 `disk=ssd` label 的節點上

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: alpine
spec:
  nodeSelector:
    disk: ssd
  containers:
  - name: alpine
    image: alpine:3.15
    command: ["sleep", "6000"]
```

```bash
kubectl apply -f alpine.yaml
kubectl get po alpine -o wide
```

## 題目 2. 節點的 taint + 帶 toleration 的 Pod `alpha`

```bash
# 在 worker 節點（帶 disk=ssd label）上加上 taint
NODE=$(kubectl get nodes -l disk=ssd -o jsonpath='{.items[0].metadata.name}')
kubectl taint nodes $NODE app_type=alpha:NoSchedule
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: alpha
spec:
  tolerations:
  - key: app_type
    operator: Equal
    value: alpha
    effect: NoSchedule
  containers:
  - name: alpha
    image: redis
```

```bash
kubectl apply -f alpha.yaml
```

## 題目 3. 在 control-plane 上的 static pod `static-busybox`

在 control-plane 節點上（透過 SSH）把清單檔放到 `/etc/kubernetes/manifests/`：

```yaml
# /etc/kubernetes/manifests/static-busybox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-busybox
  labels:
    pod-type: static-pod
spec:
  containers:
  - name: static-busybox
    image: viktoruj/ping_pong:alpine
```

kubelet 會自己把 Pod 啟動；在 API 中它會以 `static-busybox-<節點名稱>` 出現。

## 題目 4. PriorityClass + deployment

```bash
kubectl create priorityclass high-priority --value=1000000
kubectl create deployment prio-app --image=viktoruj/ping_pong:latest
kubectl patch deployment prio-app -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

## 題目 5. HPA

```bash
kubectl create deployment hpa-app --image=viktoruj/ping_pong:latest
kubectl set resources deployment hpa-app --requests=cpu=100m
kubectl autoscale deployment hpa-app --min=2 --max=10 --cpu-percent=50
```

## 題目 6. 帶 PodAntiAffinity 的 Deployment + PDB

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: important-app2
  namespace: app2-system
spec:
  replicas: 3
  selector:
    matchLabels:
      app: important-app2
  template:
    metadata:
      labels:
        app: important-app2
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: important-app2
            topologyKey: kubernetes.io/hostname
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: important-app2
        image: viktoruj/ping_pong:latest
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: important-app2
  namespace: app2-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: important-app2
```

```bash
kubectl create namespace app2-system
kubectl apply -f app2.yaml
```

## 題目 7. 透過 topologySpreadConstraints 做嚴格分佈

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spread-app
  template:
    metadata:
      labels:
        app: spread-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule       # 嚴格
        labelSelector:
          matchLabels:
            app: spread-app
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: spread-app
        image: viktoruj/ping_pong:latest
```

```bash
kubectl apply -f spread.yaml
kubectl get po -l app=spread-app -o wide     # 每個節點一個
```

**嚴格 vs 寬鬆。** `whenUnsatisfiable: DoNotSchedule` - 嚴格：如果無法平均
分配（節點數比需要的少），多出來的 Pod 會停在 `Pending`。若希望 Pods 仍然
啟動並容許一定的偏斜，請改成 **寬鬆** 模式：

```yaml
        whenUnsatisfiable: ScheduleAnyway      # 寬鬆（容許偏斜）
```

podAntiAffinity 也一樣：`requiredDuringScheduling...` - 嚴格（有 Pending 的風險），
`preferredDuringScheduling...`（搭配 `weight`）- 寬鬆（所有 Pods 都會啟動）。
