[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 07 - ეტალონური გადაწყვეტა

გამოყენებული ვერსიები:
- ძველი: Istio `1.28.1`, რევიზია `1-28-1`
- ახალი: Istio `1.29.1`, რევიზია `1-29-1`

## ნაბიჯი 1. Istio Helm რეპოზიტორიის დამატება

```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

## ნაბიჯი 2. Istio-ს ინსტალაცია Helm-ის მეშვეობით (ძველი რევიზია)

```bash
kubectl create namespace istio-system

# CRDs + cluster-wide resources
helm install istio-base istio/base -n istio-system --version 1.28.1 --set defaultRevision=1-28-1

# revisioned control plane
helm install istiod-1-28-1 istio/istiod -n istio-system --version 1.28.1 --set revision=1-28-1 --wait

kubectl get pods -n istio-system
```

## ნაბიჯი 3. ძველ რევიზიაზე მიბმული აპლიკაციის განთავსება

```bash
kubectl create namespace app
kubectl label namespace app istio.io/rev=1-28-1

kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/07/k8s-1/scripts/1.yaml
kubectl rollout restart deployment -n app

# confirm the sidecar was injected by the 1.28.1 control plane
kubectl get pods -n app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\t"}{.spec.initContainers[*].image}{"\n"}{end}'
```

## ნაბიჯი 4. Canary: ახალი რევიზიის ინსტალაცია ძველის პარალელურად

```bash
# upgrade the shared CRDs to the new version first
helm upgrade istio-base istio/base -n istio-system --version 1.29.1 --set defaultRevision=1-28-1

# install the new revisioned control plane (the old one keeps running)
helm install istiod-1-29-1 istio/istiod -n istio-system --version 1.29.1 --set revision=1-29-1 --wait

# both control planes now coexist
kubectl get pods -n istio-system
```

## ნაბიჯი 5. აპლიკაციის namespace-ის ახალ რევიზიაზე მიგრაცია

```bash
kubectl label namespace app istio.io/rev=1-29-1 --overwrite
kubectl rollout restart deployment -n app

# now the sidecars are injected by the 1.29.1 control plane
kubectl get pods -n app -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.initContainers[*].image}{"\n"}{end}'
```

## ნაბიჯი 6. (არასავალდებულო) ძველი რევიზიის წაშლა

```bash
helm uninstall istiod-1-28-1 -n istio-system
```

## შემოწმება

```bash
helm list -n istio-system
kubectl get ns app --show-labels | grep 1-29-1
kubectl get pods -n app -o jsonpath='{range .items[*]}{.spec.initContainers[*].image}{"\n"}{end}' | grep 1.29.1
```
