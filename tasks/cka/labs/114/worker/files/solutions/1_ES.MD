[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 114 — solución de referencia (troubleshooting)

La ruta de diagnóstico es siempre la misma: `get` → `describe` (Events) → `logs` → reparación.

## Tarea 1. ReplicaSet rs-app2223 (ImagePullBackOff)

```bash
kubectl get po -n rsapp                 # STATUS: ImagePullBackOff
kubectl describe po -n rsapp <pod>      # Events: no se descarga la imagen viktoruj/ping_pong:doesnotexist123
# reparamos la imagen en la plantilla del RS
kubectl edit rs rs-app2223 -n rsapp     # image: viktoruj/ping_pong:doesnotexist123 -> viktoruj/ping_pong:latest
# el RS no recrea los pods por sí mismo al cambiar la plantilla: eliminamos los pods antiguos
kubectl delete po -n rsapp -l app=rsapp
kubectl get rs rs-app2223 -n rsapp      # READY 2
```

## Tarea 2. Service svc-broken (Endpoints vacíos)

```bash
kubectl get endpoints svc-broken -n tsvc   # vacío
kubectl describe svc svc-broken -n tsvc    # selector app=WRONG
kubectl get pods -n tsvc --show-labels     # los pods tienen la etiqueta app=web
# reparamos el selector del servicio
kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpoints svc-broken -n tsvc   # han aparecido las direcciones
```

## Tarea 3. Deployment capp (CreateContainerConfigError)

```bash
kubectl get po -n cfgapp                  # CreateContainerConfigError
kubectl describe po -n cfgapp <pod>       # no se encuentra el configMap missing-config
# creamos el ConfigMap ausente
kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value
kubectl rollout status deploy capp -n cfgapp
```
