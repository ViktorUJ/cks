[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 109 - 参考解答（可観測性：プローブ、ログ、デバッグ、deprecations）

## 課題 1。livenessProbe（exec）付きの Pod `app1233`

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

## 課題 2。起動が遅いアプリケーションのための 3 つのプローブ（`web-probes`）

`DELAY_START=30` を指定した `ping_pong` アプリケーションは 30 秒後にはじめて `:8080` を
リッスンし始めます - これは起動が遅いケースの模擬です。startupProbe が起動の余裕を与え、
liveness/readiness はその成功後にだけ有効になります。

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
      failureThreshold: 12      # 起動に 5 × 12 = 60 秒の余裕
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
# 直後は 0/1（startupProbe 実行中）、およそ 30 秒後に Ready
kubectl -n web-ns get pod web-probes -w
```

「startupProbe と `initialDelaySeconds`」の比較ケースは README で解説しています。

## 課題 3。Pod のログをファイルへエクスポートする

```bash
# Pod の namespace を探す
kubectl get po -A | grep app-xyz3322
# ログを出力する
kubectl logs app-xyz3322 -n app-logs > /opt/logs/app-xyz123.log
cat /opt/logs/app-xyz123.log
```

## 課題 4。CLI スクリプト（top、events）

```bash
mkdir -p /var/work/artifact
echo 'kubectl top pods -A --sort-by=cpu' > /var/work/artifact/top.sh
echo "kubectl get events -A --sort-by='.metadata.creationTimestamp'" > /var/work/artifact/events.sh
```

## 課題 5。古いマニフェストを修正してデプロイする

ファイル `/var/work/109/app-old.yaml` は削除済みの `apps/v1beta1` を使っており、必須の
`selector` も含んでいません。現行バージョンに修正します：

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

現行の API バージョンは次のコマンドで確認できます：`kubectl explain deployment` と
`kubectl api-versions`。
