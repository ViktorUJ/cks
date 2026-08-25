[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# ლაბორატორია 01 - ეტალონური გადაწყვეტა (Istio-ს ინსტალაცია + Bookinfo)

## ნაბიჯი 1. დააინსტალირეთ istioctl

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
istioctl version --remote=false
```

## ნაბიჯი 2. დააინსტალირეთ Istio (demo პროფილი, NodePort ingress)

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

## ნაბიჯი 3. ჩართეთ sidecar ინექცია

```bash
kubectl label namespace default istio-injection=enabled
```

## ნაბიჯი 4. გაშალეთ Bookinfo

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# every pod should be 2/2 (app + istio-proxy)
kubectl get pods
```

## ნაბიჯი 5. დააკონფიგურირეთ Gateway

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

## შემოწმება

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
# <title>Simple Bookstore App</title>
```
