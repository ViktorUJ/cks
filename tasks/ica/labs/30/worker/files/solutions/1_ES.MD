[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Laboratorio 30 - Solución de referencia

Istio `1.29.1` está instalado. El espacio de nombres `app` (istio-injection) contiene un cliente
dentro de la malla, `app-client`. `istioctl` está disponible en el PC del trabajador.

## Objetivo

Ejecuta un **StatefulSet** detrás de un **Service** sin cabecera en la malla, habilita mTLS
**STRICT** y alcanza cada réplica mediante su **identidad estable por pod** (`web-0`, `web-1`)
a través de mTLS.

## Paso 1. Service sin cabecera + StatefulSet

El Service debe tener `clusterIP: None` (sin cabecera) y un puerto **con nombre** (Istio utiliza
el prefijo del nombre del puerto para la detección de protocolos). El `serviceName` del StatefulSet
debe coincidir con el Service sin cabecera para que los pods obtengan nombres DNS estables
`<pod>.<svc>.<ns>.svc.cluster.local`.

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

## Paso 2. Aplicar mTLS STRICT

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

## Paso 3. Alcanzar cada réplica mediante su identidad estable (a través de mTLS)

```bash
kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-0.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-0

kubectl exec -n app deploy/app-client -c curl -- \
  curl -s http://web-1.web.app.svc.cluster.local:8080/ | grep "Server Name"
# Server Name: web-1
```

Cada nombre DNS estable se resuelve en un pod específico, y el tráfico se cifra con mTLS mediante
los sidecars aunque el Service no tenga cabecera.

## Por qué sin cabecera + malla solía ser complicado

- Un Service **sin cabecera** tiene `clusterIP: None`, por lo que no hay IP virtual: DNS devuelve
  las IP individuales de los pods directamente. Las aplicaciones StatefulSet a menudo se conectan a un
  par **específico** (p. ej., un broker de Kafka o una réplica de base de datos) mediante su nombre estable en
  lugar de un VIP con balanceo de carga.
- Históricamente, Envoy creaba listeners en `0.0.0.0:<port>`, lo que entraba en conflicto con las aplicaciones
  que se vinculaban solo a la IP del pod, y mTLS en servicios sin cabecera era problemático. **Istio
  1.10+** gestiona los servicios sin cabecera de forma nativa: los listeners por pod y mTLS automático funcionan.
- **El nombrado de puertos sigue importando**: asigna al puerto el nombre `http`/`tcp`/`grpc`/`mongo-*`, etc.
  Un puerto sin nombre hace que Istio lo trate como TCP opaco y se pierden las funciones L7.

## Servicios sin cabecera externos (adicional)

Para un servicio sin cabecera que reside **fuera** del clúster (p. ej., un Kafka externo), añade un
`ServiceEntry` con `resolution: DNS` para que la malla pueda resolverlo y enrutar hacia él:

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
