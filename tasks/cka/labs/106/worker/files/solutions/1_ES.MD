[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 106 — solución de referencia (SecurityContext)

## Tarea 1. Pod `non-root-pod` (runAsUser 1000, fsGroup 2000)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: non-root-pod
spec:
  securityContext:
    runAsUser: 1000
    fsGroup: 2000
  containers:
  - name: non-root-pod
    image: redis:alpine
```

## Tarea 2. Pod `appsec-pod` (root + capability SYS_TIME)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: appsec-pod
spec:
  containers:
  - name: appsec-pod
    image: ubuntu:22.04
    command: ["sleep", "4800"]
    securityContext:
      capabilities:
        add: ["SYS_TIME"]
```

## Tarea 3. Deployment `deployment-app-y` (no priv escalation, not privileged)

```bash
kubectl create namespace app-y
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deployment-app-y
  namespace: app-y
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app-y
  template:
    metadata:
      labels:
        app: app-y
    spec:
      containers:
      - name: app-y
        image: viktoruj/ping_pong:alpine
        env:
        - name: SERVER_NAME
          value: app-y
        securityContext:
          allowPrivilegeEscalation: false
          privileged: false
```

## Tarea 4. Deployment `sword-app` (runAsUser 5000, no priv escalation)

```bash
kubectl create namespace swordfish
kubectl create deployment sword-app -n swordfish --image=viktoruj/ping_pong:alpine
```

Añadir el `securityContext` al contenedor (con `kubectl edit` o mediante un patch):

```yaml
        securityContext:
          runAsUser: 5000
          allowPrivilegeEscalation: false
```
