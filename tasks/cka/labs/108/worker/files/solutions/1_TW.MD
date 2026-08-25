[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 108 - 參考解答(PV、PVC、帶 volume 的 pod)

## 任務 1-3。PV + PVC + 位於節點 node_2 上的 pod

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
kubectl get po analytics -o wide     # 必須位於帶有標籤 node=node_2 的節點上
```

備註:
- PV 與 PVC 會依大小與 accessMode 相符自動綁定。
- `nodeSelector: node=node_2` 把 pod 放到 worker 節點上(hostPath `/pv/analytics` 也在那裡)。
