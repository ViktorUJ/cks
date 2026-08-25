[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 30 - リファレンスソリューション

Istio `1.29.1` がインストールされています。名前空間 `app`（istio-injection）には、メッシュ内クライアント
`app-client` が含まれます。ワーカー PC では `istioctl` を利用できます。

## 目標

メッシュ内で **headless Service** の背後に **StatefulSet** を実行し、**STRICT** mTLS を有効化して、
mTLS 経由で各レプリカの **安定した Pod 単位の ID**（`web-0`、`web-1`）に到達します。

## ステップ 1. Headless Service + StatefulSet

Service には `clusterIP: None`（headless）と **名前付き** ポートが必要です（Istio は
プロトコル検出のためにポート名のプレフィックスを使用します）。Pod が安定した DNS 名
`<pod>.<svc>.<ns>.svc.cluster.local` を取得できるよう、StatefulSet の `serviceName` は
headless Service と一致している必要があります。

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: app
  labels:
    app: web
spec:
  clusterIP: None          # headless
  selector:
    app: web
  ports:
    - name: http           # named port - required for Istio protocol detection
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
  namespace: app
spec:
  serviceName: web         # ties the pods to the headless Service
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: viktoruj/ping_pong:latest
          env:
            - name: ENABLE_DEFAULT_HOSTNAME   # report the real pod name (web-0/web-1)
              value: "false"
          ports:
            - name: http
              containerPort: 8080
EOF

kubectl rollout status statefulset/web -n app
```

## ステップ 2. STRICT mTLS を強制する

```bash
kubectl apply -f - <<'EOF'
apiVersion: security.istio.io/v1
kind: PeerAuthentication
metadata:
  name: default
  namespace: app
spec:
  mtls:
    mode: STRICT
EOF
```

## ステップ 3. 安定した ID により各レプリカへ到達する（mTLS 経由）

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-0.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-0

kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-1.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-1
```

各安定 DNS 名は特定の Pod に解決され、Service が headless であってもトラフィックは
サイドカーによって mTLS で暗号化されます。

## headless + mesh が以前は難しかった理由

- **headless** Service には `clusterIP: None` があるため、仮想 IP は存在せず、DNS は
  個々の Pod IP を直接返します。StatefulSet アプリは、ロードバランスされた VIP ではなく、
  安定した名前で **特定の** ピア（例: Kafka ブローカー、データベースレプリカ）に接続することがよくあります。
- 歴史的に Envoy は `0.0.0.0:<port>` 上にリスナーを作成しており、Pod IP のみにバインドする
  アプリと競合していました。また、headless Service 上の mTLS には問題がありました。**Istio
  1.10+** は headless Service をネイティブに処理します。Pod 単位のリスナーと自動 mTLS が機能します。
- **ポートの命名は依然として重要です**: ポートには `http`/`tcp`/`grpc`/`mongo-*` などの名前を付けます。
  名前のないポートでは Istio はそれを不透明な TCP として扱うため、L7 機能を利用できなくなります。

## 外部 headless Service（ボーナス）

クラスターの**外部**に存在する headless Service（例: 外部 Kafka）の場合は、メッシュがそれを
解決してルーティングできるよう、`resolution: DNS` を持つ `ServiceEntry` を追加します:

```yaml
apiVersion: networking.istio.io/v1
kind: ServiceEntry
metadata:
  name: kafka-ext
  namespace: app
spec:
  hosts: ["kafka.example.com"]
  location: MESH_INTERNAL
  ports:
    - name: tcp-kafka
      number: 9092
      protocol: TCP
  resolution: DNS
```
