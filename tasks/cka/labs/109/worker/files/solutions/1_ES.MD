[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 109 — solución de referencia (observabilidad: probes, logs, depuración, deprecations)

## Tarea 1. Pod `app1233` con livenessProbe (exec)

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

## Tarea 2. Tres probes para una aplicación de arranque lento (`web-probes`)

La aplicación `ping_pong` con `DELAY_START=30` empieza a escuchar en `:8080` solo al cabo de 30
segundos: es una imitación de un arranque largo. El startupProbe da margen para el arranque y
liveness/readiness se activan solo tras su éxito.

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
      failureThreshold: 12      # margen 5 × 12 = 60 s para el arranque
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
# al principio 0/1 (se ejecuta el startupProbe), aprox. a los 30 s — Ready
kubectl -n web-ns get pod web-probes -w
```

El caso «startupProbe frente a `initialDelaySeconds`» se analiza en el README.

## Tarea 3. Exportar los logs del pod a un fichero

```bash
# encontrar el namespace del pod
kubectl get po -A | grep app-xyz3322
# volcar los logs
kubectl logs app-xyz3322 -n app-logs > /opt/logs/app-xyz123.log
cat /opt/logs/app-xyz123.log
```

## Tarea 4. Scripts de CLI (top, events)

```bash
mkdir -p /var/work/artifact
echo 'kubectl top pods -A --sort-by=cpu' > /var/work/artifact/top.sh
echo "kubectl get events -A --sort-by='.metadata.creationTimestamp'" > /var/work/artifact/events.sh
```

## Tarea 5. Arreglar el manifiesto obsoleto y desplegarlo

El fichero `/var/work/109/app-old.yaml` usa la versión eliminada `apps/v1beta1` y no contiene el
`selector` obligatorio. Lo corregimos a la versión actual:

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

La versión actual de la API se puede consultar con `kubectl explain deployment` y
`kubectl api-versions`.
