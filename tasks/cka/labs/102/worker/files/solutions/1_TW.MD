[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 102 — 參考解答（更新與部署策略）

## 題目 1。Deployment `web`（viktoruj/ping_pong:latest，3 個副本）

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3
kubectl rollout status deploy web
```

## 題目 2。Rolling update `web` → viktoruj/ping_pong:alpine + 記錄原因

`kubectl create deployment` 會給容器一個自動產生的名稱（例如
`ping-pong-xxxxx`），因此在 `set image` 中比較方便的做法是使用 `*=` — 在不知道確切名稱的情況下
更新所有容器中的映像。

```bash
kubectl set image deployment/web '*=viktoruj/ping_pong:alpine'
kubectl annotate deployment/web kubernetes.io/change-cause="update to alpine" --overwrite
kubectl rollout status deploy web
kubectl rollout history deploy web
```

## 題目 3。Deployment `roll`：更新並回退到前一個版本

```bash
kubectl create deployment roll --image=viktoruj/ping_pong:latest
kubectl set image deployment/roll '*=viktoruj/ping_pong:alpine'   # 修訂版本 2
kubectl rollout status deploy roll
kubectl rollout undo deployment/roll                 # 回退到 latest（修訂版本 3）
kubectl get deploy roll -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## 題目 4。在 `canary` namespace 中做 canary（v2 取得約 30%）

共用的 Service `app` 透過標籤 `app=app` 選出兩個版本；流量比例 ≈ Pod 數量的比例
（v1=7、v2=3 → v2 ≈ 30%）。

```bash
kubectl create namespace canary
```

```yaml
# app.yaml
apiVersion: v1
kind: Service
metadata:
  name: app
  namespace: canary
spec:
  selector:
    app: app            # 同時匹配兩個版本
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v1
  namespace: canary
spec:
  replicas: 7
  selector:
    matchLabels:
      app: app
      version: v1
  template:
    metadata:
      labels:
        app: app
        version: v1
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        ports:
        - containerPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-v2
  namespace: canary
spec:
  replicas: 3
  selector:
    matchLabels:
      app: app
      version: v2
  template:
    metadata:
      labels:
        app: app
        version: v2
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
        env:
        - name: SERVER_NAME
          value: appV2
        ports:
        - containerPort: 8080
```

```bash
kubectl apply -f app.yaml
kubectl get pods -n canary -l app=app --show-labels
```

## 題目 5。推出策略（maxSurge=2，maxUnavailable=0）

```bash
kubectl patch deployment web -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'
kubectl get deploy web -o jsonpath='{.spec.strategy}'
```

`maxUnavailable: 0` + `maxSurge: 2` — 先把新的 Pod 起來，之後才關掉
舊的：推出過程中不會損失容量。

## 題目 6。Blue/Green（`bg` namespace）

```bash
kubectl create namespace bg
```

```yaml
# bg.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bg-blue
  namespace: bg
spec:
  replicas: 2
  selector:
    matchLabels:
      app: bg
      version: blue
  template:
    metadata:
      labels:
        app: bg
        version: blue
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bg-green
  namespace: bg
spec:
  replicas: 2
  selector:
    matchLabels:
      app: bg
      version: green
  template:
    metadata:
      labels:
        app: bg
        version: green
    spec:
      containers:
      - name: app
        image: viktoruj/ping_pong:latest
---
apiVersion: v1
kind: Service
metadata:
  name: bg-svc
  namespace: bg
spec:
  selector:   # 一開始流量走 blue
    app: bg
    version: blue
  ports:
  - port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f bg.yaml
# 一個動作就把 blue -> green 切換完成（變更 selector）
kubectl patch svc bg-svc -n bg -p '{"spec":{"selector":{"app":"bg","version":"green"}}}'
kubectl get endpoints bg-svc -n bg
```

回退同樣是瞬間完成 — 把 selector 改回 `version: blue`。
