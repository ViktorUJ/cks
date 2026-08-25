[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 114 — solution de référence (troubleshooting)

Le parcours de diagnostic est toujours le même : `get` → `describe` (Events) → `logs` → réparation.

## Tâche 1. ReplicaSet rs-app2223 (ImagePullBackOff)

```bash
kubectl get po -n rsapp                 # STATUS : ImagePullBackOff
kubectl describe po -n rsapp <pod>      # Events : l'image viktoruj/ping_pong:doesnotexist123 ne se télécharge pas
# on corrige l'image dans le template du RS
kubectl edit rs rs-app2223 -n rsapp     # image: viktoruj/ping_pong:doesnotexist123 -> viktoruj/ping_pong:latest
# le RS ne recrée pas les pods lui-même lors d'un changement de template — supprimons les anciens pods
kubectl delete po -n rsapp -l app=rsapp
kubectl get rs rs-app2223 -n rsapp      # READY 2
```

## Tâche 2. Service svc-broken (Endpoints vides)

```bash
kubectl get endpoints svc-broken -n tsvc   # vide
kubectl describe svc svc-broken -n tsvc    # selector app=WRONG
kubectl get pods -n tsvc --show-labels     # les pods portent le label app=web
# on corrige le sélecteur du service
kubectl patch svc svc-broken -n tsvc -p '{"spec":{"selector":{"app":"web"}}}'
kubectl get endpoints svc-broken -n tsvc   # les adresses sont apparues
```

## Tâche 3. Deployment capp (CreateContainerConfigError)

```bash
kubectl get po -n cfgapp                  # CreateContainerConfigError
kubectl describe po -n cfgapp <pod>       # configMap missing-config introuvable
# on crée le ConfigMap manquant
kubectl create configmap missing-config -n cfgapp --from-literal=KEY=value
kubectl rollout status deploy capp -n cfgapp
```
