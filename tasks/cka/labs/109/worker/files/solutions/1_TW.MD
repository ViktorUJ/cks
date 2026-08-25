[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 109 - 參考解答(可觀測性:探針、日誌、除錯、deprecations)

## 任務 1。帶 livenessProbe(exec)的 Pod `app1233`

```bash
kubectl create namespace web-ns
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app1233
  namespace: web-ns
spec:
  containers:
  - name: app1233
    image: viktoruj/ping_pong:alpine
    livenessProbe:
      exec:
        command: ["ls", "/etc"]
      initialDelaySeconds: 10
      periodSeconds: 60
```

## 任務 2。啟動緩慢的應用程式的三種探針(`web-probes`)

帶 `DELAY_START=30` 的 `ping_pong` 應用程式要等 30 秒後才會開始監聽 `:8080` -
這是模擬長時間啟動。startupProbe 提供啟動的預算,而 liveness/readiness
只有在它成功之後才會生效。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-probes
  namespace: web-ns
spec:
  containers:
  - name: web-probes
    image: viktoruj/ping_pong:latest
    ports:
    - containerPort: 8080
    env:
    - name: DELAY_START
      value: "30"
    startupProbe:
      httpGet:
        path: /
        port: 8080
      periodSeconds: 5
      failureThreshold: 12      # 啟動預算 5 × 12 = 60 秒
    readinessProbe:
      httpGet:
        path: /
        port: 8080
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /
        port: 8080
      periodSeconds: 10
```

```bash
kubectl apply -f web-probes.yaml
# 一開始是 0/1(startupProbe 正在執行),大約 30 秒後 - Ready
kubectl -n web-ns get pod web-probes -w
```

「startupProbe 與 `initialDelaySeconds` 的比較」這個案例在 README 中有剖析。

## 任務 3。把 Pod 的日誌匯出到檔案

```bash
# 找出 Pod 所在的 namespace
kubectl get po -A | grep app-xyz3322
# 匯出日誌
kubectl logs app-xyz3322 -n app-logs > /opt/logs/app-xyz123.log
cat /opt/logs/app-xyz123.log
```

## 任務 4。CLI 腳本(top、events)

```bash
mkdir -p /var/work/artifact
echo 'kubectl top pods -A --sort-by=cpu' > /var/work/artifact/top.sh
echo "kubectl get events -A --sort-by='.metadata.creationTimestamp'" > /var/work/artifact/events.sh
```

## 任務 5。修復過時的清單並部署

檔案 `/var/work/109/app-old.yaml` 使用了已被移除的 `apps/v1beta1`,且不包含
必填的 `selector`。我們把它改成目前的版本:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-21
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-21
  template:
    metadata:
      labels:
        app: app-21
    spec:
      containers:
      - name: app-21
        image: viktoruj/ping_pong:alpine
```

```bash
kubectl apply -f /var/work/109/app-old.yaml
kubectl get deploy app-21
```

目前的 API 版本可以這樣查看:`kubectl explain deployment` 與
`kubectl api-versions`。
