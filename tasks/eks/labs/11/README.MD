# ArgoCD

## install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

## get admin password
```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo

```
## port forward
```bash
kubectl port-forward svc/argocd-server -n argocd 9090:443 --address 0.0.0.0

```
## login to ArgoCD
```
http://{worker-node-ip}:9090  
```