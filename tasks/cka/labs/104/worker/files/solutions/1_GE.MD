[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD)

# Lab 104 — ეტალონური ამოხსნა (დაგეგმვა, რესურსები, HPA)

## დავალება 1. Pod `alpine` node-ზე ლეიბლით `disk=ssd`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: alpine
spec:
  nodeSelector:
    disk: ssd
  containers:
  - name: alpine
    image: alpine:3.15
    command: ["sleep", "6000"]
```

```bash
kubectl apply -f alpine.yaml
kubectl get po alpine -o wide
```

## დავალება 2. node-ის taint + pod `alpha` toleration-ით

```bash
# ვდებთ taint-ს worker-node-ზე (ლეიბლით disk=ssd)
NODE=$(kubectl get nodes -l disk=ssd -o jsonpath='{.items[0].metadata.name}')
kubectl taint nodes $NODE app_type=alpha:NoSchedule
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: alpha
spec:
  tolerations:
  - key: app_type
    operator: Equal
    value: alpha
    effect: NoSchedule
  containers:
  - name: alpha
    image: redis
```

```bash
kubectl apply -f alpha.yaml
```

## დავალება 3. Static pod `static-busybox` control-plane-ზე

control-plane node-ზე (SSH-ით) მოათავსეთ მანიფესტი `/etc/kubernetes/manifests/`-ში:

```yaml
# /etc/kubernetes/manifests/static-busybox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: static-busybox
  labels:
    pod-type: static-pod
spec:
  containers:
  - name: static-busybox
    image: viktoruj/ping_pong:alpine
```

kubelet თავად აწევს pod-ს; API-ში ის გამოჩნდება როგორც `static-busybox-<node-ის-სახელი>`.

## დავალება 4. PriorityClass + deployment

```bash
kubectl create priorityclass high-priority --value=1000000
kubectl create deployment prio-app --image=viktoruj/ping_pong:latest
kubectl patch deployment prio-app -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

## დავალება 5. HPA

```bash
kubectl create deployment hpa-app --image=viktoruj/ping_pong:latest
kubectl set resources deployment hpa-app --requests=cpu=100m
kubectl autoscale deployment hpa-app --min=2 --max=10 --cpu-percent=50
```

## დავალება 6. Deployment PodAntiAffinity-ით + PDB

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: important-app2
  namespace: app2-system
spec:
  replicas: 3
  selector:
    matchLabels:
      app: important-app2
  template:
    metadata:
      labels:
        app: important-app2
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: important-app2
            topologyKey: kubernetes.io/hostname
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: important-app2
        image: viktoruj/ping_pong:latest
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: important-app2
  namespace: app2-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: important-app2
```

```bash
kubectl create namespace app2-system
kubectl apply -f app2.yaml
```

## დავალება 7. მკაცრი განაწილება topologySpreadConstraints-ით

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: spread-app
  template:
    metadata:
      labels:
        app: spread-app
    spec:
      topologySpreadConstraints:
      - maxSkew: 1
        topologyKey: kubernetes.io/hostname
        whenUnsatisfiable: DoNotSchedule       # მკაცრად
        labelSelector:
          matchLabels:
            app: spread-app
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: spread-app
        image: viktoruj/ping_pong:latest
```

```bash
kubectl apply -f spread.yaml
kubectl get po -l app=spread-app -o wide     # თითო node-ზე ერთი
```

**მკაცრი vs რბილი.** `whenUnsatisfiable: DoNotSchedule` — მკაცრად: თუ თანაბრად განაწილება
შეუძლებელია (node-ები საჭიროზე ნაკლებია), ზედმეტი pod დარჩება `Pending` მდგომარეობაში.
იმისთვის, რომ pod-ები მაინც გაეშვას გადახრის დაშვებით, შეცვალეთ **რბილი** რეჟიმით:

```yaml
        whenUnsatisfiable: ScheduleAnyway      # რბილად (გადახრის დაშვებით)
```

ანალოგიურად podAntiAffinity-სთან: `requiredDuringScheduling...` — მკაცრად (Pending-ის
რისკი), `preferredDuringScheduling...` (`weight`-ით) — რბილად (ყველა pod გაეშვება).
