[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [日本語版](README_JP.MD)

# Lab 121 - 參考解答(RBAC 快速訓練)

namespace `rbac` 已預先建立。加速用設定:

```bash
alias k=kubectl
export do="--dry-run=client -o yaml"
```

## 快速訓練

```bash
# 1. ServiceAccount
kubectl -n rbac create serviceaccount app-sa

# 2. Role:讀取 Pods
kubectl -n rbac create role pod-reader \
  --verb=get,list,watch --resource=pods

# 3. RoleBinding:pod-reader -> app-sa
kubectl -n rbac create rolebinding read-pods \
  --role=pod-reader --serviceaccount=rbac:app-sa

# 4. ClusterRole:檢視 nodes
kubectl create clusterrole cr-viewer \
  --verb=get,list --resource=nodes

# 5. ClusterRoleBinding:cr-viewer -> app-sa
kubectl create clusterrolebinding crb-viewer \
  --clusterrole=cr-viewer --serviceaccount=rbac:app-sa
```

## 檢查有效權限

```bash
kubectl auth can-i get pods    -n rbac --as=system:serviceaccount:rbac:app-sa   # yes
kubectl auth can-i get nodes            --as=system:serviceaccount:rbac:app-sa   # yes
kubectl auth can-i delete pods -n rbac --as=system:serviceaccount:rbac:app-sa   # no
```

文件:[Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/),
[kubectl auth can-i](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#checking-api-access)。

## 驗證

```bash
check_result
```
