[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 122 — solution de référence (exercices de scheduling)

Le namespace `sched` est créé à l'avance. Le cluster est mono-nœud — les labels et les
taints sont posés sur l'unique nœud. Nom du nœud : `kubectl get nodes`.

> **Ordre :** faites la tâche 6 (taint) **en dernier** — le taint `NoSchedule` empêchera de
> planifier les pods sans toleration.

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

## 1. Label sur le nœud

```bash
kubectl label node $NODE disk=ssd
```

## 2. Pod avec nodeSelector

```bash
kubectl -n sched run sel --image=viktoruj/ping_pong:latest --overrides='
{"spec":{"nodeSelector":{"disk":"ssd"}}}'
```

## 3. Pod avec nodeAffinity

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

## 4. Pod avec requests/limits

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

## 6. Taint + Pod avec toleration (à faire en dernier)

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

Documentation : [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/),
[Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/),
[Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/).

## Vérification

```bash
check_result
```
