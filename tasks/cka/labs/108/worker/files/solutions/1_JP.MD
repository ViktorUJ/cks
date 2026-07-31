[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 108 - 参考解答（PV、PVC、volume を使う Pod）

## 課題 1-3。PV + PVC + ノード node_2 上の Pod

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-analytics
spec:
  capacity:
    storage: 100Mi
  accessModes: ["ReadWriteOnce"]
  hostPath:
    path: /pv/analytics
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-analytics
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 100Mi
---
apiVersion: v1
kind: Pod
metadata:
  name: analytics
spec:
  nodeSelector:
    node: node_2
  containers:
  - name: analytics
    image: viktoruj/ping_pong:alpine
    volumeMounts:
    - name: data
      mountPath: /pv/analytics
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: pvc-analytics
```

```bash
kubectl apply -f pv.yaml
kubectl get pv,pvc
kubectl get po analytics -o wide     # label node=node_2 を持つノード上にあるはず
```

補足：
- PV と PVC はサイズと accessMode の一致によって自動的に結び付きます。
- `nodeSelector: node=node_2` は Pod を worker ノードに配置します（hostPath `/pv/analytics` も同じノードにあります）。
