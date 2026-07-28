[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 108 — Referenzlösung (PV, PVC, Pod mit Volume)

## Aufgaben 1-3. PV + PVC + Pod auf dem Node node_2

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
kubectl get po analytics -o wide     # muss auf dem Node mit dem Label node=node_2 laufen
```

Hinweise:
- PV und PVC werden automatisch verbunden, wenn Größe und accessMode übereinstimmen.
- `nodeSelector: node=node_2` platziert den Pod auf dem Worker-Node (dort liegt auch der hostPath `/pv/analytics`).
