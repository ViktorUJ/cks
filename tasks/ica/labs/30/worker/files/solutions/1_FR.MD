[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 30 - Solution de référence

Istio `1.29.1` est installé. L'espace de noms `app` (istio-injection) contient un client dans le mesh
`app-client`. `istioctl` est disponible sur le PC worker.

## Objectif

Exécuter un **StatefulSet** derrière un **Service** **headless** dans le mesh, activer le mTLS
**STRICT** et atteindre chaque réplique grâce à son **identité stable par pod** (`web-0`, `web-1`) via mTLS.

## Étape 1. Service headless + StatefulSet

Le Service doit avoir `clusterIP: None` (headless) et un port **nommé** (Istio utilise le
préfixe du nom du port pour la détection du protocole). Le `serviceName` du StatefulSet doit correspondre au
Service headless afin que les pods obtiennent des noms DNS stables `<pod>.<svc>.<ns>.svc.cluster.local`.

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

## Étape 2. Appliquer mTLS STRICT

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

## Étape 3. Atteindre chaque réplique par son identité stable (via mTLS)

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-0.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-0

kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-1.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-1
```

Chaque nom DNS stable est résolu vers un pod spécifique, et le trafic est chiffré par mTLS par les
sidecars, même si le Service est headless.

## Pourquoi headless + mesh était autrefois délicat

- Un Service **headless** a `clusterIP: None`, donc il n'y a pas d'IP virtuelle : le DNS renvoie
  directement les IP individuelles des pods. Les applications StatefulSet se connectent souvent à un pair
  **spécifique** (p. ex. un broker Kafka, une réplique de base de données) par son nom stable plutôt qu'à une VIP avec équilibrage de charge.
- Historiquement, Envoy créait des listeners sur `0.0.0.0:<port>`, ce qui entrait en conflit avec des applications
  qui se liaient uniquement à l'IP du pod, et le mTLS sur les services headless était problématique. **Istio
  1.10+** gère nativement les services headless : les listeners par pod et le mTLS automatique fonctionnent.
- **Le nommage des ports reste important** : nommez le port `http`/`tcp`/`grpc`/`mongo-*` etc. Un
  port sans nom conduit Istio à le traiter comme du TCP opaque et vous perdez les fonctionnalités L7.

## Services headless externes (bonus)

Pour un service headless situé **hors** du cluster (p. ex. un Kafka externe), ajoutez une
`ServiceEntry` avec `resolution: DNS` afin que le mesh puisse le résoudre et y router le trafic :

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
