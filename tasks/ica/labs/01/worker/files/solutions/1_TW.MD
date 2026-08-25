[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [日本語版](1_JP.MD)

# 實驗 01 - 參考解答（安裝 Istio + Bookinfo）

## 步驟 1. 安裝 istioctl

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
istioctl version --remote=false
```

## 步驟 2. 安裝 Istio（demo 設定檔，NodePort ingress）

```bash
cat <<EOF > istio-kubeadm.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  components:
    ingressGateways:
    - name: istio-ingressgateway
      k8s:
        service:
          type: NodePort
          ports:
          - port: 80
            targetPort: 8080
            nodePort: 32080
            name: http2
          - port: 443
            targetPort: 8443
            nodePort: 32443
            name: https
EOF

istioctl install -f istio-kubeadm.yaml -y

kubectl get pods -n istio-system
```

## 步驟 3. 啟用 sidecar 注入

```bash
kubectl label namespace default istio-injection=enabled
```

## 步驟 4. 部署 Bookinfo

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# every pod should be 2/2 (app + istio-proxy)
kubectl get pods
```

## 步驟 5. 設定 Gateway

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

## 驗證

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
# <title>Simple Bookstore App</title>
```
