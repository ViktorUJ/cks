[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD)

# Lab 115 - 参考解答（CRD、Helm、Kustomize）

## 課題 1。CRD を作成する

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

## 課題 2。Prometheus の Helm chart をインストールする

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install prom prometheus-community/kube-prometheus-stack -n monitoring
helm ls -n monitoring
```

## 課題 3。Kustomize overlay を適用する

ファイルはすでに `/var/work/115/kustomize` に準備されています（base + overlay `dev`、namespace は
`kustns`、`replicas: 3`）。

```bash
kubectl create namespace kustns
# 何が生成されるか確認する
kubectl kustomize /var/work/115/kustomize/overlays/dev
# 適用する
kubectl apply -k /var/work/115/kustomize/overlays/dev
kubectl get deploy kapp -n kustns      # replicas 3
```
