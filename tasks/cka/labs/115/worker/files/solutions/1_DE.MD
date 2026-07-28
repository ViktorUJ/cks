[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD)

# Lab 115 — Referenzlösung (CRD, Helm, Kustomize)

## Aufgabe 1. Eine CRD erstellen

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

## Aufgabe 2. Den Prometheus-Helm-Chart installieren

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prom prometheus-community/kube-prometheus-stack -n monitoring
helm ls -n monitoring
```

## Aufgabe 3. Das Kustomize-Overlay anwenden

Die Dateien sind bereits in `/var/work/115/kustomize` vorbereitet (base + overlay `dev` mit
Namespace `kustns` und `replicas: 3`).

```bash
kubectl create namespace kustns
# ansehen, was dabei herauskommt
kubectl kustomize /var/work/115/kustomize/overlays/dev
# anwenden
kubectl apply -k /var/work/115/kustomize/overlays/dev
kubectl get deploy kapp -n kustns      # replicas 3
```
