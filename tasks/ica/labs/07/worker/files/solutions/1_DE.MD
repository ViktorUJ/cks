[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 07 - Referenzlösung

Verwendete Versionen:
- ALT: Istio `1.28.1`, Revision `1-28-1`
- NEU: Istio `1.29.1`, Revision `1-29-1`

## Schritt 1. Das Istio-Helm-Repository hinzufügen

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

## Schritt 2. Istio über Helm installieren (alte Revision)

```bash
kubectl create namespace istio-system

# CRDs + cluster-wide resources
helm install istio-base istio/base -n istio-system --version 1.28.1 --set defaultRevision=1-28-1

# revisioned control plane
helm install istiod-1-28-1 istio/istiod -n istio-system --version 1.28.1 --set revision=1-28-1 --wait

kubectl get pods -n istio-system
```

## Schritt 3. Die auf die alte Revision festgelegte App bereitstellen

```bash
kubectl create namespace app
kubectl label namespace app istio.io/rev=1-28-1

kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/07/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n app

# confirm the sidecar was injected by the 1.28.1 control plane
kubectl get pods -n app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\t"}{.spec.initContainers[*].image}{"\n"}{end}'
```

## Schritt 4. Canary: Die neue Revision parallel zur alten installieren

```bash
# upgrade the shared CRDs to the new version first
helm upgrade istio-base istio/base -n istio-system --version 1.29.1 --set defaultRevision=1-28-1

# install the new revisioned control plane (the old one keeps running)
helm install istiod-1-29-1 istio/istiod -n istio-system --version 1.29.1 --set revision=1-29-1 --wait

# both control planes now coexist
kubectl get pods -n istio-system
```

## Schritt 5. Den App-Namespace auf die neue Revision migrieren

```bash
kubectl label namespace app istio.io/rev=1-29-1 --overwrite
kubectl rollout restart deployment -n app

# now the sidecars are injected by the 1.29.1 control plane
kubectl get pods -n app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.initContainers[*].image}{"\n"}{end}'
```

## Schritt 6. (optional) Die alte Revision entfernen

```bash
helm uninstall istiod-1-28-1 -n istio-system
```

## Überprüfen

```bash
helm list -n istio-system
kubectl get ns app --show-labels | grep 1-29-1
kubectl get pods -n app -o jsonpath='{range .items[*]}{.spec.initContainers[*].image}{"\n"}{end}' | grep 1.29.1
```
