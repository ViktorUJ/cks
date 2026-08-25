[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 102 — solution de référence (mises à jour et stratégies de déploiement)

## Tâche 1. Deployment `web` (viktoruj/ping_pong:latest, 3 réplicas)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3
kubectl rollout status deploy web
```

## Tâche 2. Rolling update de `web` → viktoruj/ping_pong:alpine + enregistrer la raison

`kubectl create deployment` donne au conteneur un nom généré automatiquement (par exemple,
`ping-pong-xxxxx`) ; c'est pourquoi il est plus pratique d'utiliser `*=` dans `set image` — mettre
à jour l'image dans tous les conteneurs sans connaître le nom exact.

```bash
kubectl set image deployment/web '*=viktoruj/ping_pong:alpine'
kubectl annotate deployment/web kubernetes.io/change-cause="update to alpine" --overwrite
kubectl rollout status deploy web
kubectl rollout history deploy web
```

## Tâche 3. Deployment `roll` : mettre à jour et revenir à la version précédente

```bash
kubectl create deployment roll --image=viktoruj/ping_pong:latest
kubectl set image deployment/roll '*=viktoruj/ping_pong:alpine'   # révision 2
kubectl rollout status deploy roll
kubectl rollout undo deployment/roll                 # retour à latest (révision 3)
kubectl get deploy roll -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Tâche 4. Canary dans le namespace `canary` (v2 reçoit ~30%)

Le Service commun `app` sélectionne les deux versions via le label `app=app` ; la part du trafic
≈ la part des pods (v1=7, v2=3 → v2 ≈ 30%).

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
    app: app            # attrape les deux versions
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

## Tâche 5. Stratégie de déploiement (maxSurge=2, maxUnavailable=0)

```bash
kubectl patch deployment web -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'
kubectl get deploy web -o jsonpath='{.spec.strategy}'
```

`maxUnavailable: 0` + `maxSurge: 2` — les nouveaux pods démarrent d'abord, et seulement ensuite
les anciens sont arrêtés : la capacité n'est pas perdue pendant le déploiement.

## Tâche 6. Blue/Green (namespace `bg`)

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
  selector:   # au départ, le trafic va vers blue
    app: bg
    version: blue
  ports:
  - port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f bg.yaml
# bascule blue -> green en un seul geste (changement de sélecteur)
kubectl patch svc bg-svc -n bg -p '{"spec":{"selector":{"app":"bg","version":"green"}}}'
kubectl get endpoints bg-svc -n bg
```

Le retour arrière est tout aussi instantané : remettre le sélecteur sur `version: blue`.
