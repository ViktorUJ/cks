[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 — ეტალონური ამოხსნა (CRD, Helm, Kustomize)

## დავალება 1. შექმენით CRD

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: operators.stable.example.com
spec:
  group: stable.example.com
  scope: Namespaced
  names:
    plural: operators
    singular: operator
    kind: Operator
    shortNames: ["op"]
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              email:
                type: string
              name:
                type: string
              age:
                type: integer
```

```bash
kubectl apply -f crd.yaml
kubectl get crd operators.stable.example.com
```

## დავალება 2. დააყენეთ Prometheus-ის Helm-chart

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prom prometheus-community/kube-prometheus-stack -n monitoring
helm ls -n monitoring
```

## დავალება 3. გამოიყენეთ Kustomize-overlay

ფაილები უკვე მომზადებულია `/var/work/115/kustomize`-ში (base + overlay `dev` namespace
`kustns`-ით და `replicas: 3`-ით).

```bash
kubectl create namespace kustns
# ვნახოთ, რა გამოვა
kubectl kustomize /var/work/115/kustomize/overlays/dev
# გამოყენება
kubectl apply -k /var/work/115/kustomize/overlays/dev
kubectl get deploy kapp -n kustns      # replicas 3
```
