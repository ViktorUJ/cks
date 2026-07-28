[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 102 — Referenzlösung (Updates und Deployment-Strategien)

## Aufgabe 1. Deployment `web` (viktoruj/ping_pong:latest, 3 Replicas)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3
kubectl rollout status deploy web
```

## Aufgabe 2. Rolling Update von `web` → viktoruj/ping_pong:alpine + Grund festhalten

`kubectl create deployment` gibt dem Container einen automatisch generierten Namen (zum Beispiel
`ping-pong-xxxxx`), deshalb ist es in `set image` bequemer, `*=` anzugeben — das Image in allen
Containern zu aktualisieren, ohne den genauen Namen zu kennen.

```bash
kubectl set image deployment/web '*=viktoruj/ping_pong:alpine'
kubectl annotate deployment/web kubernetes.io/change-cause="update to alpine" --overwrite
kubectl rollout status deploy web
kubectl rollout history deploy web
```

## Aufgabe 3. Deployment `roll`: aktualisieren und auf die vorherige Version zurückrollen

```bash
kubectl create deployment roll --image=viktoruj/ping_pong:latest
kubectl set image deployment/roll '*=viktoruj/ping_pong:alpine'   # Revision 2
kubectl rollout status deploy roll
kubectl rollout undo deployment/roll                 # Rollback auf latest (Revision 3)
kubectl get deploy roll -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Aufgabe 4. Canary im Namespace `canary` (v2 erhält ~30%)

Der gemeinsame Service `app` wählt beide Versionen über das Label `app=app` aus; der Anteil des
Traffics ≈ dem Anteil der Pods (v1=7, v2=3 → v2 ≈ 30%).

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
    app: app            # erfasst beide Versionen
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

## Aufgabe 5. Rollout-Strategie (maxSurge=2, maxUnavailable=0)

```bash
kubectl patch deployment web -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'
kubectl get deploy web -o jsonpath='{.spec.strategy}'
```

`maxUnavailable: 0` + `maxSurge: 2` — zuerst starten die neuen Pods, erst danach werden die alten
beendet: Während des Rollouts geht keine Kapazität verloren.

## Aufgabe 6. Blue/Green (Namespace `bg`)

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
  selector:   # zunächst geht der Traffic auf blue
    app: bg
    version: blue
  ports:
  - port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f bg.yaml
# Umschalten blue -> green in einem Zug (Selector wechseln)
kubectl patch svc bg-svc -n bg -p '{"spec":{"selector":{"app":"bg","version":"green"}}}'
kubectl get endpoints bg-svc -n bg
```

Der Rollback ist genauso sofortig — den Selector zurück auf `version: blue` setzen.
