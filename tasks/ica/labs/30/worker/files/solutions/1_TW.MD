[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 30 - 參考解答

已安裝 Istio `1.29.1`。命名空間 `app`（istio-injection）包含一個網格內用戶端
`app-client`。工作機電腦上可使用 `istioctl`。

## 目標

在網格中於 **headless Service** 後方執行一個 **StatefulSet**，啟用 **STRICT** mTLS，
並透過 mTLS 使用每個副本的**穩定每 Pod 身分**（`web-0`、`web-1`）連線至它們。

## 步驟 1：Headless Service + StatefulSet

Service 必須具有 `clusterIP: None`（headless），以及一個**具名**連接埠（Istio 會使用連接埠名稱
前綴進行協定偵測）。StatefulSet 的 `serviceName` 必須與 headless Service 相符，
讓 Pod 獲得穩定的 DNS 名稱 `<pod>.<svc>.<ns>.svc.cluster.local`。

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

## 步驟 2：強制執行 STRICT mTLS

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

## 步驟 3：透過穩定身分連線至每個副本（經由 mTLS）

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-0.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-0

kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-1.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-1
```

每個穩定 DNS 名稱都會解析至特定 Pod，即使 Service 是 headless，流量仍由 sidecar
進行 mTLS 加密。

## 為什麼 headless + mesh 曾經棘手

- **headless** Service 具有 `clusterIP: None`，因此沒有虛擬 IP，DNS 會直接傳回
  個別 Pod IP。StatefulSet 應用程式通常透過穩定名稱連線至**特定**對等端
  （例如 Kafka broker、資料庫副本），而非負載平衡的 VIP。
- 在過去，Envoy 會在 `0.0.0.0:<port>` 上建立 listener，這與僅繫結至 Pod IP 的應用程式
  衝突，且 headless service 上的 mTLS 曾有問題。**Istio
  1.10+** 原生支援 headless service：每 Pod listener 與自動 mTLS 均可運作。
- **連接埠命名仍然重要**：將連接埠命名為 `http`/`tcp`/`grpc`/`mongo-*` 等。未命名的
  連接埠會讓 Istio 將其視為不透明 TCP，因而失去 L7 功能。

## 外部 headless service（加分）

對於位於叢集**外部**的 headless service（例如外部 Kafka），新增一個具有
`resolution: DNS` 的 `ServiceEntry`，讓 mesh 可以解析並路由至它：

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
