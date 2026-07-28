[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 104 — solution de référence (planification, ressources, HPA)

## Tâche 1. Pod `alpine` sur le nœud portant le label `disk=ssd`

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

## Tâche 2. Taint du nœud + pod `alpha` avec toleration

```bash
# on pose le taint sur le nœud worker (celui qui porte le label disk=ssd)
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

## Tâche 3. Static pod `static-busybox` sur le control-plane

Sur le nœud control-plane (en SSH), déposez le manifeste dans `/etc/kubernetes/manifests/` :

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

kubelet démarre le pod de lui-même ; dans l'API il apparaît comme `static-busybox-<nom-du-nœud>`.

## Tâche 4. PriorityClass + deployment

```bash
kubectl create priorityclass high-priority --value=1000000
kubectl create deployment prio-app --image=viktoruj/ping_pong:latest
kubectl patch deployment prio-app -p '{"spec":{"template":{"spec":{"priorityClassName":"high-priority"}}}}'
```

## Tâche 5. HPA

```bash
kubectl create deployment hpa-app --image=viktoruj/ping_pong:latest
kubectl set resources deployment hpa-app --requests=cpu=100m
kubectl autoscale deployment hpa-app --min=2 --max=10 --cpu-percent=50
```

## Tâche 6. Deployment avec PodAntiAffinity + PDB

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

## Tâche 7. Distribution stricte via topologySpreadConstraints

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
        whenUnsatisfiable: DoNotSchedule       # STRICT
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
kubectl get po -l app=spread-app -o wide     # un par nœud
```

**Strict vs souple.** `whenUnsatisfiable: DoNotSchedule` est strict : si une répartition
égale est impossible (il y a moins de nœuds que nécessaire), le pod en trop restera
`Pending`. Pour que les pods démarrent malgré tout en tolérant un écart, passez au mode
**souple** :

```yaml
        whenUnsatisfiable: ScheduleAnyway      # SOUPLE (écart toléré)
```

Il en va de même pour podAntiAffinity : `requiredDuringScheduling...` est strict (risque de
Pending), `preferredDuringScheduling...` (avec un `weight`) est souple (tous les pods
démarreront).
