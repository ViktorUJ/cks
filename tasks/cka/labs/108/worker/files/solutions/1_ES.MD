[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 — solución de referencia (PV, PVC, pod con volumen)

## Tareas 1-3. PV + PVC + pod en el nodo node_2

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
kubectl get po analytics -o wide     # debe estar en el nodo con la etiqueta node=node_2
```

Notas:
- El PV y el PVC se enlazan automáticamente cuando coinciden el tamaño y el accessMode.
- `nodeSelector: node=node_2` coloca el pod en el nodo worker (allí mismo está el hostPath `/pv/analytics`).
