[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 — ეტალონური ამოხსნა (troubleshooting)

დიაგნოსტიკის მარშრუტი ერთია: `get` → `describe` (Events) → `logs` → შესწორება.

## დავალება 1. ReplicaSet rs-app2223 (ImagePullBackOff)

```bash
kubectl get po -n rsapp                 # STATUS: ImagePullBackOff
kubectl describe po -n rsapp <pod>      # Events: არ ჩამოიწევა image viktoruj/ping_pong:doesnotexist123
# ვასწორებთ image-ს RS-ის შაბლონში
kubectl edit rs rs-app2223 -n rsapp     # image: viktoruj/ping_pong:doesnotexist123 -> viktoruj/ping_pong:latest
# RS შაბლონის შეცვლისას pod-ებს თავად არ ქმნის ხელახლა — წავშალოთ ძველი pod-ები
kubectl delete po -n rsapp -l app=rsapp
kubectl get rs rs-app2223 -n rsapp      # READY 2
```

## დავალება 2. Service svc-broken (ცარიელი Endpoints)

```bash
kubectl get endpoints svc-broken -n tsvc   # ცარიელია
kubectl describe svc svc-broken -n tsvc    # selector app=WRONG
kubectl get pods -n tsvc --show-labels     # pod-ებს აქვთ ლეიბლი app=web
# ვასწორებთ სერვისის სელექტორს
kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpoints svc-broken -n tsvc   # გამოჩნდა მისამართები
```

## დავალება 3. Deployment capp (CreateContainerConfigError)

```bash
kubectl get po -n cfgapp                  # CreateContainerConfigError
kubectl describe po -n cfgapp <pod>       # ვერ მოიძებნა configMap missing-config
# ვქმნით არარსებულ ConfigMap-ს
kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value
kubectl rollout status deploy capp -n cfgapp
```
