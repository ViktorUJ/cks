[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Deutsche Version](README_DE.MD) · [ქართული ვერსია](README_GE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 115 — solution de référence (CRD, Helm, Kustomize)

## Tâche 1. Créer la CRD

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

## Tâche 2. Installer le chart Helm de Prometheus

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prom prometheus-community/kube-prometheus-stack -n monitoring
helm ls -n monitoring
```

## Tâche 3. Appliquer l'overlay Kustomize

Les fichiers sont déjà préparés dans `/var/work/115/kustomize` (base + overlay `dev` avec le
namespace `kustns` et `replicas: 3`).

```bash
kubectl create namespace kustns
# voir ce que cela va donner
kubectl kustomize /var/work/115/kustomize/overlays/dev
# appliquer
kubectl apply -k /var/work/115/kustomize/overlays/dev
kubectl get deploy kapp -n kustns      # replicas 3
```
