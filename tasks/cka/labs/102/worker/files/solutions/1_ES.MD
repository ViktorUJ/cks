[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 102 — solución de referencia (actualizaciones y estrategias de despliegue)

## Tarea 1. Deployment `web` (viktoruj/ping_pong:latest, 3 réplicas)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3
kubectl rollout status deploy web
```

## Tarea 2. Rolling update de `web` → viktoruj/ping_pong:alpine + registrar el motivo

`kubectl create deployment` asigna al contenedor un nombre autogenerado (por ejemplo,
`ping-pong-xxxxx`), por eso en `set image` resulta más cómodo usar `*=` — actualizar la imagen
en todos los contenedores sin conocer el nombre exacto.

```bash
kubectl set image deployment/web '*=viktoruj/ping_pong:alpine'
kubectl annotate deployment/web kubernetes.io/change-cause="update to alpine" --overwrite
kubectl rollout status deploy web
kubectl rollout history deploy web
```

## Tarea 3. Deployment `roll`: actualizar y volver a la versión anterior

```bash
kubectl create deployment roll --image=viktoruj/ping_pong:latest
kubectl set image deployment/roll '*=viktoruj/ping_pong:alpine'   # revisión 2
kubectl rollout status deploy roll
kubectl rollout undo deployment/roll                 # vuelta a latest (revisión 3)
kubectl get deploy roll -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Tarea 4. Canary en el namespace `canary` (v2 recibe ~30%)

El Service común `app` selecciona ambas versiones por la label `app=app`; la proporción de
tráfico ≈ la proporción de pods (v1=7, v2=3 → v2 ≈ 30%).

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
    app: app            # captura ambas versiones
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

## Tarea 5. Estrategia de despliegue (maxSurge=2, maxUnavailable=0)

```bash
kubectl patch deployment web -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'
kubectl get deploy web -o jsonpath='{.spec.strategy}'
```

`maxUnavailable: 0` + `maxSurge: 2` — primero se levantan los pods nuevos y solo después se
apagan los viejos: no se pierde capacidad durante el despliegue.

## Tarea 6. Blue/Green (namespace `bg`)

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
  selector:   # al principio el tráfico va a blue
    app: bg
    version: blue
  ports:
  - port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f bg.yaml
# cambio blue -> green de un solo movimiento (cambiar el selector)
kubectl patch svc bg-svc -n bg -p '{"spec":{"selector":{"app":"bg","version":"green"}}}'
kubectl get endpoints bg-svc -n bg
```

La vuelta atrás es igual de inmediata: devolver el selector a `version: blue`.
