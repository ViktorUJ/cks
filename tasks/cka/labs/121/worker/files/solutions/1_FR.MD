[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 121 — solution de référence (drills RBAC)

Le namespace `rbac` est créé à l'avance. Accélérateurs :

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## Drills

```bash
# 1. ServiceAccount
kubectl -n rbac create serviceaccount app-sa

# 2. Role : lecture des pods
kubectl -n rbac create role pod-reader \
  --verb=get,list,watch --resource=pods

# 3. RoleBinding : pod-reader -> app-sa
kubectl -n rbac create rolebinding read-pods \
  --role=pod-reader --serviceaccount=rbac:app-sa

# 4. ClusterRole : consultation des nodes
kubectl create clusterrole cr-viewer \
  --verb=get,list --resource=nodes

# 5. ClusterRoleBinding : cr-viewer -> app-sa
kubectl create clusterrolebinding crb-viewer \
  --clusterrole=cr-viewer --serviceaccount=rbac:app-sa
```

## Vérification des droits effectifs

```bash
kubectl auth can-i get pods    -n rbac --as=system:serviceaccount:rbac:app-sa   # yes
kubectl auth can-i get nodes            --as=system:serviceaccount:rbac:app-sa   # yes
kubectl auth can-i delete pods -n rbac --as=system:serviceaccount:rbac:app-sa   # no
```

Documentation : [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/),
[kubectl auth can-i](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access).

## Vérification

```bash
check_result
```
