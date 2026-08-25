[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD)

# Lab 102 — 参考解答 (更新とデプロイ戦略)

## 課題 1. Deployment `web` (viktoruj/ping_pong:latest、3 レプリカ)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3
kubectl rollout status deploy web
```

## 課題 2. Rolling update `web` → viktoruj/ping_pong:alpine + 理由の記録

`kubectl create deployment` はコンテナに自動生成された名前を付けます (たとえば
`ping-pong-xxxxx`)。そのため `set image` では `*=` を指定するのが便利です - 正確な名前を
知らなくても、すべてのコンテナのイメージを更新できます。

```bash
kubectl set image deployment/web '*=viktoruj/ping_pong:alpine'
kubectl annotate deployment/web kubernetes.io/change-cause="update to alpine" --overwrite
kubectl rollout status deploy web
kubectl rollout history deploy web
```

## 課題 3. Deployment `roll`：更新して直前のバージョンへ切り戻す

```bash
kubectl create deployment roll --image=viktoruj/ping_pong:latest
kubectl set image deployment/roll '*=viktoruj/ping_pong:alpine'   # リビジョン 2
kubectl rollout status deploy roll
kubectl rollout undo deployment/roll                 # latest へ切り戻し (リビジョン 3)
kubectl get deploy roll -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## 課題 4. namespace `canary` での canary (v2 が約 30% を受け取る)

共通の Service `app` はラベル `app=app` で両方のバージョンを選びます。トラフィックの割合
≈ Pod の割合です (v1=7、v2=3 → v2 ≈ 30%)。

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
    app: app            # 両方のバージョンを捕まえる
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

## 課題 5. 展開戦略 (maxSurge=2、maxUnavailable=0)

```bash
kubectl patch deployment web -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'
kubectl get deploy web -o jsonpath='{.spec.strategy}'
```

`maxUnavailable: 0` + `maxSurge: 2` - まず新しい Pod が立ち上がり、そのあとで古い Pod が
落とされます。展開の途中で処理能力が失われません。

## 課題 6. Blue/Green (namespace `bg`)

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
  selector:   # 最初はトラフィックは blue へ
    app: bg
    version: blue
  ports:
  - port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f bg.yaml
# blue -> green を一手で切り替え (セレクターの変更)
kubectl patch svc bg-svc -n bg -p '{"spec":{"selector":{"app":"bg","version":"green"}}}'
kubectl get endpoints bg-svc -n bg
```

切り戻しも同じく瞬時です - セレクターを `version: blue` に戻すだけです。
