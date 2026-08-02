[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 108 — ეტალონური ამოხსნა (PV, PVC, pod ტომით)

## დავალებები 1-3. PV + PVC + pod node_2 კვანძზე

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
kubectl get po analytics -o wide     # უნდა იყოს node=node_2 ლეიბლის მქონე კვანძზე
```

შენიშვნები:
- PV და PVC ავტომატურად უკავშირდებიან ერთმანეთს ზომისა და accessMode-ის დამთხვევისას.
- `nodeSelector: node=node_2` pod-ს სვამს worker-კვანძზე (სადაც არის hostPath `/pv/analytics`).
