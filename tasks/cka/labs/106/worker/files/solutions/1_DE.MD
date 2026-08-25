[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 106 — Referenzlösung (SecurityContext)

## Aufgabe 1. Pod `non-root-pod` (runAsUser 1000, fsGroup 2000)

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

## Aufgabe 2. Pod `appsec-pod` (root + Capability SYS_TIME)

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

## Aufgabe 3. Deployment `deployment-app-y` (no priv escalation, not privileged)

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

## Aufgabe 4. Deployment `sword-app` (runAsUser 5000, no priv escalation)

```bash
kubectl create namespace swordfish
kubectl create deployment sword-app -n swordfish --image=viktoruj/ping_pong:alpine
```

Dem Container `securityContext` hinzufügen (über `kubectl edit` oder einen Patch):

```yaml
        securityContext:
          runAsUser: 5000
          allowPrivilegeEscalation: false
```
