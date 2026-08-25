[Русская версия](1_RU.MD) · [Eng version](1.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Lab 01 - Solución de referencia (Instalar Istio + Bookinfo)

## Paso 1. Instalar istioctl

```bash
version=1.29.1
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$version sh -
sudo mv istio-$version/bin/istioctl /usr/local/bin/
istioctl version --remote=false
```

## Paso 2. Instalar Istio (perfil demo, ingreso NodePort)

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

## Paso 3. Habilitar la inyección de sidecar

```bash
kubectl label namespace default istio-injection=enabled
```

## Paso 4. Desplegar Bookinfo

```bash
cd istio-1.29.1
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

# every pod should be 2/2 (app + istio-proxy)
kubectl get pods
```

## Paso 5. Configurar el Gateway

```bash
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
```

## Verificar

```bash
curl -s http://myapp.local:32080/productpage | grep -o "<title>.*</title>"
# <title>Simple Bookstore App</title>
```
