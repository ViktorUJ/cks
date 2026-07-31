[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 114 — Referenzlösung (Troubleshooting)

Die Diagnose-Route ist immer dieselbe: `get` → `describe` (Events) → `logs` → Reparatur.

## Aufgabe 1. ReplicaSet rs-app2223 (ImagePullBackOff)

```bash
kubectl get po -n rsapp                 # STATUS: ImagePullBackOff
kubectl describe po -n rsapp <pod>      # Events: das Image viktoruj/ping_pong:doesnotexist123 wird nicht gezogen
# wir korrigieren das Image im RS-Template
kubectl edit rs rs-app2223 -n rsapp     # image: viktoruj/ping_pong:doesnotexist123 -> viktoruj/ping_pong:latest
# das RS erstellt die Pods bei einer Template-Änderung nicht selbst neu — löschen wir die alten Pods
kubectl delete po -n rsapp -l app=rsapp
kubectl get rs rs-app2223 -n rsapp      # READY 2
```

## Aufgabe 2. Service svc-broken (leere Endpoints)

```bash
kubectl get endpoints svc-broken -n tsvc   # leer
kubectl describe svc svc-broken -n tsvc    # selector app=WRONG
kubectl get pods -n tsvc --show-labels     # die Pods tragen das Label app=web
# wir korrigieren den Selector des Services
kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpoints svc-broken -n tsvc   # die Adressen sind erschienen
```

## Aufgabe 3. Deployment capp (CreateContainerConfigError)

```bash
kubectl get po -n cfgapp                  # CreateContainerConfigError
kubectl describe po -n cfgapp <pod>       # configMap missing-config nicht gefunden
# wir erstellen die fehlende ConfigMap
kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value
kubectl rollout status deploy capp -n cfgapp
```
