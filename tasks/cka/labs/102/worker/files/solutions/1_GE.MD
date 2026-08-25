[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 102 — ეტალონური ამოხსნა (განახლებები და განთავსების სტრატეგიები)

## დავალება 1. Deployment `web` (viktoruj/ping_pong:latest, 3 რეპლიკა)

```bash
kubectl create deployment web --image=viktoruj/ping_pong:latest --replicas=3
kubectl rollout status deploy web
```

## დავალება 2. Rolling update `web` → viktoruj/ping_pong:alpine + მიზეზის ჩაწერა

`kubectl create deployment` კონტეინერს ავტომატურად გენერირებულ სახელს ანიჭებს (მაგალითად,
`ping-pong-xxxxx`), ამიტომ `set image`-ში მოსახერხებელია `*=`-ის მითითება — image განაახლოს
ყველა კონტეინერში ზუსტი სახელის ცოდნის გარეშე.

```bash
kubectl set image deployment/web '*=viktoruj/ping_pong:alpine'
kubectl annotate deployment/web kubernetes.io/change-cause="update to alpine" --overwrite
kubectl rollout status deploy web
kubectl rollout history deploy web
```

## დავალება 3. Deployment `roll`: განახლება და წინა ვერსიაზე დაბრუნება

```bash
kubectl create deployment roll --image=viktoruj/ping_pong:latest
kubectl set image deployment/roll '*=viktoruj/ping_pong:alpine'   # რევიზია 2
kubectl rollout status deploy roll
kubectl rollout undo deployment/roll                 # დაბრუნება latest-ზე (რევიზია 3)
kubectl get deploy roll -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## დავალება 4. Canary namespace `canary`-ში (v2 იღებს ~30%-ს)

საერთო სერვისი `app` ორივე ვერსიას ირჩევს ლეიბლით `app=app`; ტრაფიკის წილი ≈ pod-ების წილს
(v1=7, v2=3 → v2 ≈ 30%).

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
    app: app            # იჭერს ორივე ვერსიას
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

## დავალება 5. გამოშვების სტრატეგია (maxSurge=2, maxUnavailable=0)

```bash
kubectl patch deployment web -p '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxSurge":2,"maxUnavailable":0}}}}'
kubectl get deploy web -o jsonpath='{.spec.strategy}'
```

`maxUnavailable: 0` + `maxSurge: 2` — თავდაპირველად ეშვება ახალი pod-ები და მხოლოდ შემდეგ
ითიშება ძველები: სიმძლავრე გამოშვების მსვლელობაში არ იკლებს.

## დავალება 6. Blue/Green (namespace `bg`)

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
  selector:   # საწყისად ტრაფიკი blue-ზე მიდის
    app: bg
    version: blue
  ports:
  - port: 8080
    targetPort: 8080
```

```bash
kubectl apply -f bg.yaml
# გადართვა blue -> green ერთი მოძრაობით (სელექტორის შეცვლა)
kubectl patch svc bg-svc -n bg -p '{"spec":{"selector":{"app":"bg","version":"green"}}}'
kubectl get endpoints bg-svc -n bg
```

დაბრუნება ისევე მყისიერია — სელექტორი უკან `version: blue`-ზე დავაბრუნოთ.
