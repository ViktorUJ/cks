[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 122 — ეტალონური ამოხსნა (scheduling-დრილები)

namespace `sched` წინასწარ შექმნილია. კლასტერი ერთკვანძიანია — ლეიბლებს/taint-ებს ერთადერთ
node-ზე ვკიდებთ. node-ის სახელი: `kubectl get nodes`.

> **რიგითობა:** დავალება 6 (taint) შეასრულეთ **ბოლოს** — taint `NoSchedule` ხელს შეუშლის
> toleration-ის გარეშე pod-ების დაგეგმვას.

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

## 1. ლეიბლი node-ზე

```bash
kubectl label node $NODE disk=ssd
```

## 2. Pod nodeSelector-ით

```bash
kubectl -n sched run sel --image=viktoruj/ping_pong:latest --overrides='
{"spec":{"nodeSelector":{"disk":"ssd"}}}'
```

## 3. Pod nodeAffinity-ით

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

## 4. Pod requests/limits-ით

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

## 6. Taint + Pod toleration-ით (ბოლოს შესასრულებელი)

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

დოკუმენტაცია: [Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/),
[Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/),
[Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/).

## შემოწმება

```bash
check_result
```
