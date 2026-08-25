[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 104 - 参考解答（スケジューリング、リソース、HPA）

## 課題 1. label `disk=ssd` を持つノードへの Pod `alpine`

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

## 課題 2. ノードの taint + toleration 付きの Pod `alpha`

```bash
# worker ノード（label disk=ssd 付き）に taint を設定する
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

## 課題 3. control-plane 上の static pod `static-busybox`

control-plane ノードで（SSH 経由で）マニフェストを `/etc/kubernetes/manifests/` に置きます:

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

kubelet が自分で Pod を起動します。API 上では `static-busybox-<ノード名>` として現れます。

## 課題 4. PriorityClass + deployment

```bash
kubectl create priorityclass high-priority --value=1000000
kubectl create deployment prio-app --image=viktoruj/ping_pong:latest
kubectl patch deployment prio-app -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

## 課題 5. HPA

```bash
kubectl create deployment hpa-app --image=viktoruj/ping_pong:latest
kubectl set resources deployment hpa-app --requests=cpu=100m
kubectl autoscale deployment hpa-app --min=2 --max=10 --cpu-percent=50
```

## 課題 6. PodAntiAffinity 付きの Deployment + PDB

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

## 課題 7. topologySpreadConstraints による厳格な分布

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
        whenUnsatisfiable: DoNotSchedule       # 厳格
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
kubectl get po -l app=spread-app -o wide     # 1 ノードに 1 つずつ
```

**厳格 vs 緩やか。** `whenUnsatisfiable: DoNotSchedule` は厳格です: 均等に配置できない場合
（ノード数が必要数より少ない場合）、余った Pod は `Pending` のまま残ります。偏りを許容してでも
Pod を起動させたいなら、**緩やか** なモードに置き換えます:

```yaml
        whenUnsatisfiable: ScheduleAnyway      # 緩やか（偏りを許容）
```

podAntiAffinity も同様です: `requiredDuringScheduling...` は厳格（Pending のリスクあり）、
`preferredDuringScheduling...`（`weight` 付き）は緩やか（すべての Pod が起動します）。
