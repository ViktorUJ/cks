[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# Lab 07 - 參考解答

使用的版本：
- 舊版：Istio `1.28.1`，修訂版 `1-28-1`
- 新版：Istio `1.29.1`，修訂版 `1-29-1`

## 步驟 1. 新增 Istio Helm 儲存庫

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

## 步驟 2. 透過 Helm 安裝 Istio（舊修訂版）

```bash
kubectl create namespace istio-system

# CRDs + cluster-wide resources
helm install istio-base istio/base -n istio-system --version 1.28.1 --set defaultRevision=1-28-1

# revisioned control plane
helm install istiod-1-28-1 istio/istiod -n istio-system --version 1.28.1 --set revision=1-28-1 --wait

kubectl get pods -n istio-system
```

## 步驟 3. 部署固定使用舊修訂版的應用程式

```bash
kubectl create namespace app
kubectl label namespace app istio.io/rev=1-28-1

kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/07/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n app

# confirm the sidecar was injected by the 1.28.1 control plane
kubectl get pods -n app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\t"}{.spec.initContainers[*].image}{"\n"}{end}'
```

## 步驟 4. 金絲雀：與舊修訂版並行安裝新修訂版

```bash
# upgrade the shared CRDs to the new version first
helm upgrade istio-base istio/base -n istio-system --version 1.29.1 --set defaultRevision=1-28-1

# install the new revisioned control plane (the old one keeps running)
helm install istiod-1-29-1 istio/istiod -n istio-system --version 1.29.1 --set revision=1-29-1 --wait

# both control planes now coexist
kubectl get pods -n istio-system
```

## 步驟 5. 將應用程式命名空間遷移至新修訂版

```bash
kubectl label namespace app istio.io/rev=1-29-1 --overwrite
kubectl rollout restart deployment -n app

# now the sidecars are injected by the 1.29.1 control plane
kubectl get pods -n app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.initContainers[*].image}{"\n"}{end}'
```

## 步驟 6. （選用）移除舊修訂版

```bash
helm uninstall istiod-1-28-1 -n istio-system
```

## 驗證

```bash
helm list -n istio-system
kubectl get ns app --show-labels | grep 1-29-1
kubectl get pods -n app -o jsonpath='{range .items[*]}{.spec.initContainers[*].image}{"\n"}{end}' | grep 1.29.1
```
