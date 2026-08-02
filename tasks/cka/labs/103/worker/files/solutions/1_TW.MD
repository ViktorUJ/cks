[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 103 — 參考解答 (Jobs、CronJob、DaemonSet)

## 題目 1。Job `hi-job`

```bash
kubectl create job hi-job --image=busybox --dry-run=client -o yaml -- /bin/sh -c 'echo hello world' > hi.yaml
# 加上 completions、backoffLimit、restartPolicy Never
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hi-job
spec:
  completions: 3
  backoffLimit: 6
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: hi-job
        image: busybox
        command: ["/bin/sh", "-c", "echo hello world"]
```

```bash
kubectl apply -f hi.yaml
```

## 題目 2。namespace `rnd` 中的 CronJob `cron-job1`

```bash
kubectl create namespace rnd
```

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cron-job1
  namespace: rnd
spec:
  schedule: "*/15 * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 5
  failedJobsHistoryLimit: 7
  jobTemplate:
    spec:
      completions: 3
      backoffLimit: 4
      activeDeadlineSeconds: 10
      template:
        spec:
          restartPolicy: Never
          containers:
          - name: cron-job1
            image: viktoruj/ping_pong:alpine
            imagePullPolicy: IfNotPresent
            command: ["/bin/sh", "-c", "echo 'Hello from CKAD mock'"]
```

```bash
kubectl apply -f cron.yaml
```

## 題目 3。在所有節點上的 DaemonSet `important-app` (包括 control-plane)

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: important-app
  namespace: app-system
spec:
  selector:
    matchLabels:
      app: important-app
  template:
    metadata:
      labels:
        app: important-app
    spec:
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: important-app
        image: viktoruj/ping_pong:latest
```

```bash
kubectl create namespace app-system
kubectl apply -f ds.yaml
kubectl get ds important-app -n app-system -o wide
```

針對 control-plane taint 的 toleration 可保證 DaemonSet 的 Pod 也會在
master 節點上啟動 — 因此每個節點上都會有一個 Pod。
