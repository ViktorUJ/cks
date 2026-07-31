[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 122 - 参考解答（スケジューリングのドリル）

namespace `sched` は事前に作成済みです。クラスタは単一ノード構成で、ラベルと taint は
唯一のノードに付けます。ノード名の確認：`kubectl get nodes`。

> **順番：**課題 6（taint）は**最後に**実施してください - `NoSchedule` taint は
> toleration を持たない Pod のスケジューリングを妨げます。

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

## 1. ノードへのラベル

```bash
kubectl label node $NODE disk=ssd
```

## 2. nodeSelector 付きの Pod

```bash
kubectl -n sched run sel --image=viktoruj/ping_pong:latest --overrides='
{"spec":{"nodeSelector":{"disk":"ssd"}}}'
```

## 3. nodeAffinity 付きの Pod

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

## 4. requests/limits 付きの Pod

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

## 6. Taint + toleration 付きの Pod（最後に実施）

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

ドキュメント：[Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/),
[Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/),
[Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)。

## チェック

```bash
check_result
```
