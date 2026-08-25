[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 122 — Referenzlösung (Scheduling-Drills)

Der Namespace `sched` ist vorab erstellt. Der Cluster hat einen Node — Labels und Taints
hängen wir an den einzigen Node. Node-Name: `kubectl get nodes`.

> **Reihenfolge:** Aufgabe 6 (Taint) **als Letztes** erledigen — der Taint `NoSchedule`
> verhindert das Einplanen von Pods ohne Toleration.

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

## 1. Label auf dem Node

```bash
kubectl label node $NODE disk=ssd
```

## 2. Pod mit nodeSelector

```bash
kubectl -n sched run sel --image=viktoruj/ping_pong:latest --overrides='
{"spec":{"nodeSelector":{"disk":"ssd"}}}'
```

## 3. Pod mit nodeAffinity

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: aff
  namespace: sched
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disk
            operator: In
            values: [ssd]
  containers:
  - name: c
    image: viktoruj/ping_pong:latest
EOF
```

## 4. Pod mit requests/limits

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: res
  namespace: sched
spec:
  containers:
  - name: c
    image: viktoruj/ping_pong:latest
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
      limits:
        cpu: "200m"
        memory: "128Mi"
EOF
```

## 5. PriorityClass + Pod

```bash
kubectl create priorityclass high-prio --value=1000

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: prio
  namespace: sched
spec:
  priorityClassName: high-prio
  containers:
  - name: c
    image: viktoruj/ping_pong:latest
EOF
```

## 6. Taint + Pod mit Toleration (als Letztes machen)

```bash
kubectl taint node $NODE dedicated=special:NoSchedule

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: tol
  namespace: sched
spec:
  tolerations:
  - key: dedicated
    operator: Equal
    value: special
    effect: NoSchedule
  containers:
  - name: c
    image: viktoruj/ping_pong:latest
EOF
```

Dokumentation: [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/),
[Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/),
[Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/).

## Prüfung

```bash
check_result
```
