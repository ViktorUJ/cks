[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Labor 01 – Referenzlösung (Istio + Bookinfo installieren)

## Schritt 1. istioctl installieren

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
istioctl version --remote=false
```

## Schritt 2. Istio installieren (Demo-Profil, NodePort-Ingress)

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

## Schritt 3. Sidecar-Injektion aktivieren

```bash
kubectl label namespace default istio-injection=enabled
```

## Schritt 4. Bookinfo bereitstellen

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# every pod should be 2/2 (app + istio-proxy)
kubectl get pods
```

## Schritt 5. Gateway konfigurieren

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

## Überprüfen

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
# <title>Simple Bookstore App</title>
```
