[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 30 - Referenzlösung

Istio `1.29.1` ist installiert. Der Namespace `app` (istio-injection) enthält einen In-Mesh-Client
`app-client`. `istioctl` ist auf dem Worker-PC verfügbar.

## Ziel

Betreibe ein **StatefulSet** hinter einem **headless Service** im Mesh, aktiviere **STRICT** mTLS
und erreiche jede Replik über ihre **stabile Pod-spezifische Identität** (`web-0`, `web-1`) mittels mTLS.

## Schritt 1. Headless Service + StatefulSet

Der Service muss `clusterIP: None` (headless) und einen **benannten** Port haben (Istio verwendet das
Präfix des Portnamens für die Protokollerkennung). `serviceName` des StatefulSets muss zum headless
Service passen, damit Pods stabile DNS-Namen `<pod>.<svc>.<ns>.svc.cluster.local` erhalten.

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

## Schritt 2. STRICT mTLS erzwingen

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

## Schritt 3. Jede Replik über ihre stabile Identität erreichen (mittels mTLS)

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-0.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-0

kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-1.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-1
```

Jeder stabile DNS-Name wird zu einem bestimmten Pod aufgelöst, und der Datenverkehr wird durch die
Sidecars mit mTLS verschlüsselt, obwohl der Service headless ist.

## Warum headless + Mesh früher schwierig war

- Ein **headless** Service hat `clusterIP: None`, daher gibt es keine virtuelle IP. DNS liefert die
  einzelnen Pod-IPs direkt zurück. StatefulSet-Anwendungen verbinden sich häufig mit einem **bestimmten**
  Peer (z. B. Kafka-Broker, Datenbankreplik) über seinen stabilen Namen statt mit einer lastverteilten VIP.
- Früher erstellte Envoy Listener auf `0.0.0.0:<port>`, was mit Anwendungen kollidierte, die nur an
  die Pod-IP gebunden waren, und mTLS bei headless Services war problematisch. **Istio
  1.10+** unterstützt headless Services nativ: Pod-spezifische Listener und automatisches mTLS funktionieren.
- **Portbenennung ist weiterhin wichtig**: Benenne den Port `http`/`tcp`/`grpc`/`mongo-*` usw. Ein
  unbenannter Port führt dazu, dass Istio ihn als undurchsichtiges TCP behandelt, wodurch L7-Funktionen verloren gehen.

## Externe headless Services (Bonus)

Für einen headless Service, der **außerhalb** des Clusters liegt (z. B. ein externer Kafka), füge einen
`ServiceEntry` mit `resolution: DNS` hinzu, damit das Mesh ihn auflösen und zu ihm routen kann:

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
