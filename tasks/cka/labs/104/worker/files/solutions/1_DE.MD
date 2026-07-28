[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 104 — Referenzlösung (Scheduling, Ressourcen, HPA)

## Aufgabe 1. Pod `alpine` auf dem Node mit dem Label `disk=ssd`

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

## Aufgabe 2. Taint auf dem Node + Pod `alpha` mit Toleration

```bash
# wir setzen den Taint auf den Worker-Node (den mit dem Label disk=ssd)
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

## Aufgabe 3. Static Pod `static-busybox` auf der Control-Plane

Lege auf dem Control-Plane-Node (per SSH) das Manifest in `/etc/kubernetes/manifests/`:

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

kubelet startet den Pod von selbst; in der API erscheint er als `static-busybox-<Node-Name>`.

## Aufgabe 4. PriorityClass + Deployment

```bash
kubectl create priorityclass high-priority --value=1000000
kubectl create deployment prio-app --image=viktoruj/ping_pong:latest
kubectl patch deployment prio-app -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

## Aufgabe 5. HPA

```bash
kubectl create deployment hpa-app --image=viktoruj/ping_pong:latest
kubectl set resources deployment hpa-app --requests=cpu=100m
kubectl autoscale deployment hpa-app --min=2 --max=10 --cpu-percent=50
```

## Aufgabe 6. Deployment mit PodAntiAffinity + PDB

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

## Aufgabe 7. Harte Verteilung über topologySpreadConstraints

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
        whenUnsatisfiable: DoNotSchedule       # HART
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
kubectl get po -l app=spread-app -o wide     # einer pro Node
```

**Hart vs weich.** `whenUnsatisfiable: DoNotSchedule` ist hart: wenn sich die Pods nicht
gleichmäßig verteilen lassen (es gibt weniger Nodes als nötig), bleibt der überzählige Pod
`Pending`. Damit die
Pods dennoch starten und ein Schiefstand zugelassen wird, wechsle in den **weichen** Modus:

```yaml
        whenUnsatisfiable: ScheduleAnyway      # WEICH (mit Toleranz für Schiefstand)
```

Analog bei podAntiAffinity: `requiredDuringScheduling...` ist hart (Risiko von Pending),
`preferredDuringScheduling...` (mit `weight`) ist weich (alle Pods starten).
