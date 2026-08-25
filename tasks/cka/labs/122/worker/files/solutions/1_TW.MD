[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 122 - 參考解答(排程速練)

namespace `sched` 已預先建立。叢集為單節點 - 標籤/污點都掛在唯一的那個
節點上。取得節點名稱:`kubectl get nodes`。

> **順序:**任務 6(taint)請**放到最後**做 - `NoSchedule` 污點會讓沒有
> toleration 的 Pod 無法排程。

```bash
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

## 1. 節點上的標籤

```bash
kubectl label node $NODE disk=ssd
```

## 2. 帶 nodeSelector 的 Pod

```bash
kubectl -n sched run sel --image=viktoruj/ping_pong:latest --overrides='
{"spec":{"nodeSelector":{"disk":"ssd"}}}'
```

## 3. 帶 nodeAffinity 的 Pod

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

## 4. 帶 requests/limits 的 Pod

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

## 6. Taint + 帶 toleration 的 Pod(放到最後做)

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

文件:[Assigning Pods to Nodes](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)、
[Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)、
[Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)。

## 檢查

```bash
check_result
```
