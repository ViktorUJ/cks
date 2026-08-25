[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 109 — ეტალონური ამოხსნა (დაკვირვებადობა: probe-ები, ლოგები, გამართვა, deprecations)

## დავალება 1. Pod `app1233` livenessProbe-ით (exec)

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

## დავალება 2. სამი probe ნელა მშვები აპლიკაციისთვის (`web-probes`)

აპლიკაცია `ping_pong` `DELAY_START=30`-ით `:8080`-ის მოსმენას მხოლოდ 30 წამის შემდეგ იწყებს —
ეს ხანგრძლივი გაშვების იმიტაციაა. startupProbe იძლევა მარაგს გაშვებაზე, ხოლო liveness/readiness
ერთვება მხოლოდ მისი წარმატების შემდეგ.

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
      failureThreshold: 12      # მარაგი 5 × 12 = 60 წ გაშვებაზე
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
# თავიდან 0/1 (მიდის startupProbe), დაახლოებით 30 წ-ის შემდეგ — Ready
kubectl -n web-ns get pod web-probes -w
```

კეისი „startupProbe `initialDelaySeconds`-ის წინააღმდეგ“ განხილულია README-ში.

## დავალება 3. pod-ის ლოგების ექსპორტი ფაილში

```bash
# pod-ის namespace-ის მოძებნა
kubectl get po -A | grep app-xyz3322
# ლოგების გადმოტვირთვა
kubectl logs app-xyz3322 -n app-logs > /opt/logs/app-xyz123.log
cat /opt/logs/app-xyz123.log
```

## დავალება 4. CLI-სკრიპტები (top, events)

```bash
mkdir -p /var/work/artifact
echo 'kubectl top pods -A --sort-by=cpu' > /var/work/artifact/top.sh
echo "kubectl get events -A --sort-by='.metadata.creationTimestamp'" > /var/work/artifact/events.sh
```

## დავალება 5. მოძველებული მანიფესტის შეკეთება და განთავსება

ფაილი `/var/work/109/app-old.yaml` იყენებს წაშლილ `apps/v1beta1`-ს და არ შეიცავს სავალდებულო
`selector`-ს. ვასწორებთ აქტუალურ ვერსიაზე:

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

API-ის აქტუალური ვერსია შეიძლება ნახოთ: `kubectl explain deployment` და
`kubectl api-versions`.
