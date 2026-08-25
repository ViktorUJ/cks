[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# ラボ 103 — リファレンス解答 (Jobs、CronJob、DaemonSet)

## 課題 1. Job `hi-job`

```bash
kubectl create job hi-job --image=busybox --dry-run=client -o yaml -- /bin/sh -c 'echo hello world' > hi.yaml
# completions、backoffLimit、restartPolicy Never を追加する
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

## 課題 2. namespace `rnd` の CronJob `cron-job1`

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

## 課題 3. すべてのノード (control-plane を含む) で動く DaemonSet `important-app`

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

control-plane の taint への toleration によって、DaemonSet の Pod は master ノードでも
起動します — そのため Pod が各ノードに 1 つずつ配置されます。
